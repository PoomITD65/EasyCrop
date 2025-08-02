# ==============================================================================
# firebase_listener_service.py (เวอร์ชันทำงานตลอดเวลา + แก้ไข Bug)
# ==============================================================================

import os
import sys
import io
import base64
import time
import json
import threading
from dotenv import load_dotenv

from PIL import Image
import face_recognition
from rembg import remove
import firebase_admin
from firebase_admin import credentials, db

# --- 1. การตั้งค่าและเชื่อมต่อกับ Firebase ---
print("--- [Listener Service] กำลังเริ่มต้นและเชื่อมต่อกับ Firebase ---")
load_dotenv()
try:
    base64_encoded_key = os.getenv("FIREBASE_SERVICE_ACCOUNT_BASE64")
    if base64_encoded_key:
        print("   - พบ Service Account Key ใน Environment Variable (Base64), กำลังถอดรหัส...")
        decoded_key = base64.b64decode(base64_encoded_key).decode('utf-8')
        cred_obj = json.loads(decoded_key)
        cred = credentials.Certificate(cred_obj)
    else:
        print("   - ไม่พบ Key ใน Environment Variable, กำลังอ่านจากไฟล์...")
        SERVICE_ACCOUNT_KEY_PATH = "key/idphoto-e5a75-firebase-adminsdk-fbsvc-fd771fc15f.json"
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)

    FIREBASE_DATABASE_URL = "https://idphoto-e5a75-default-rtdb.asia-southeast1.firebasedatabase.app/"
    app_name = 'listener_service'
    if app_name not in firebase_admin._apps:
        firebase_admin.initialize_app(cred, {'databaseURL': FIREBASE_DATABASE_URL}, name=app_name)
    app = firebase_admin.get_app(name=app_name)
    print("✅ (Listener Service) เชื่อมต่อ Firebase สำเร็จแล้ว!")
except Exception as e:
    print(f"❌ (Listener Service) เกิดข้อผิดพลาดในการเชื่อมต่อ Firebase: {e}")
    sys.exit()

# --- 2. การตั้งค่าสำหรับการประมวลผลภาพ ---
FINAL_IMAGE_WIDTH = 350
FINAL_IMAGE_HEIGHT = 425
NEW_BACKGROUND_COLOR = (107, 142, 232)
FRAME_TO_FACE_HEIGHT_RATIO = 3.0
EYE_LINE_POSITION_RATIO = 0.35

# --- 3. ฟังก์ชันหลักสำหรับประมวลผลรูปภาพ ---
def process_image_from_base64(base64_string):
    try:
        image_bytes = base64.b64decode(base64_string)
        pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image_array = face_recognition.load_image_file(io.BytesIO(image_bytes))
    except Exception as e:
        return False, f"ไม่สามารถถอดรหัส Base64 หรือเปิดภาพได้: {e}"

    face_landmarks_list = face_recognition.face_landmarks(image_array)
    if not face_landmarks_list: return False, "ไม่พบใบหน้า"
    if len(face_landmarks_list) > 1: return False, f"พบ {len(face_landmarks_list)} ใบหน้า"
    
    landmarks = face_landmarks_list[0]
    try:
        eyebrow_pts = landmarks['left_eyebrow'] + landmarks['right_eyebrow']
        chin_pts = landmarks['chin']
        top_of_face_y, bottom_of_face_y = min(p[1] for p in eyebrow_pts), max(p[1] for p in chin_pts)
        face_height = bottom_of_face_y - top_of_face_y
        if face_height <= 0: return False, "คำนวณความสูงใบหน้าไม่ได้"
        
        left_eye_pts, right_eye_pts = landmarks['left_eye'], landmarks['right_eye']
        eye_center_x = sum(p[0] for p in left_eye_pts + right_eye_pts) / len(left_eye_pts + right_eye_pts)
        eye_center_y = sum(p[1] for p in left_eye_pts + right_eye_pts) / len(left_eye_pts + right_eye_pts)
        
        aspect_ratio = FINAL_IMAGE_WIDTH / FINAL_IMAGE_HEIGHT
        crop_height = face_height * FRAME_TO_FACE_HEIGHT_RATIO
        crop_width = crop_height * aspect_ratio
        eye_position_in_crop = crop_height * EYE_LINE_POSITION_RATIO
        top_offset = eye_center_y - eye_position_in_crop
        left_offset = eye_center_x - (crop_width / 2)
        initial_crop_box = (int(left_offset), int(top_offset), int(left_offset + crop_width), int(top_offset + crop_height))
        
        cropped_image = pil_image.crop(initial_crop_box)
        
        foreground_image = remove(
            cropped_image, model="u2net_human_seg", alpha_matting=True,
            alpha_matting_foreground_threshold=240, alpha_matting_background_threshold=10,
            alpha_matting_erode_size=10
        )
        
        new_background = Image.new("RGB", cropped_image.size, NEW_BACKGROUND_COLOR)
        new_background.paste(foreground_image, (0, 0), foreground_image)
        final_image = new_background.resize((FINAL_IMAGE_WIDTH, FINAL_IMAGE_HEIGHT), Image.LANCZOS)
        
        return True, final_image
    except Exception as e:
        return False, f"เกิดข้อผิดพลาดระหว่างประมวลผล: {e}"

# --- 4. ฟังก์ชันสำหรับจัดการข้อมูลที่เข้ามา ---
def handle_photo_data(school_name, student_id, data):
    print(f"\n[▶️] เริ่มทำงานกับ: {school_name}/{student_id}")
    student_photo_ref = db.reference(f'schools/{school_name}/students/{student_id}/photoData', app=app)
    raw_base64_data = data.get('photoBase64')
    if not raw_base64_data:
        print("   -> ⚠️ ไม่พบข้อมูล photoBase64, ข้ามรายการนี้")
        student_photo_ref.update({'photoStatus': 'error', 'error': 'Missing photoBase64 data'})
        return

    print(f"   -> [⚙️] กำลังส่งไปประมวลผล...")
    success, result = process_image_from_base64(raw_base64_data)

    if success:
        processed_image = result
        print(f"   -> [✅] ประมวลผลสำเร็จ!")
        
        buffer_large = io.BytesIO()
        processed_image.save(buffer_large, format="JPEG")
        processed_base64_large = base64.b64encode(buffer_large.getvalue()).decode('utf-8')

        processed_image.thumbnail((128, 128))
        buffer_small = io.BytesIO()
        processed_image.save(buffer_small, format="JPEG", quality=75)
        processed_base64_small = base64.b64encode(buffer_small.getvalue()).decode('utf-8')

        final_data = {
            'photoBase64': processed_base64_large,
            'photoThumbnailBase64': processed_base64_small,
            'photoStatus': 'finish',
            'finishedAt': int(time.time() * 1000)
        }
        
        try:
            student_photo_ref.update(final_data)
            print(f"   -> [✅] อัปเดตข้อมูลรูปภาพของ {student_id} เรียบร้อย")
        except Exception as e:
            print(f"   -> [❌] เกิดข้อผิดพลาดตอนอัปเดตข้อมูล: {e}")
    else:
        error_message = result
        print(f"   -> [❌] ประมวลผลไม่สำเร็จ: {error_message}")
        try:
            student_photo_ref.update({'photoStatus': 'error', 'error': error_message})
        except Exception as e:
            print(f"   -> [❌] เกิดข้อผิดพลาดตอนอัปเดตสถานะ Error: {e}")

# --- 5. ฟังก์ชันสำหรับจัดการเมื่อมีข้อมูลเปลี่ยนแปลง (Listener Callback) ---
def listener_callback(event):
    if event.event_type not in ['put', 'patch'] or event.path == "/" or event.data is None:
        return
    
    path_parts = event.path.strip("/").split("/")
    
    if len(path_parts) == 4 and path_parts[1] == "students" and path_parts[3] == "photoData":
        school_name = path_parts[0]
        student_id = path_parts[2]
        photo_data = event.data

        if isinstance(photo_data, dict) and photo_data.get('photoStatus') == 'processed':
            print(f"[🔔] ตรวจพบรูปภาพใหม่ (Direct Update): {school_name}/{student_id}")
            handle_photo_data(school_name, student_id, photo_data)

    elif len(path_parts) == 3 and path_parts[1] == "students":
        school_name = path_parts[0]
        student_id = path_parts[2]
        student_data = event.data

        if isinstance(student_data, dict):
            photo_data = student_data.get('photoData', {})
            if isinstance(photo_data, dict) and photo_data.get('photoStatus') == 'processed':
                print(f"[🔔] ตรวจพบรูปภาพใหม่ (Parent Update): {school_name}/{student_id}")
                handle_photo_data(school_name, student_id, photo_data)

# --- 6. ส่วนหลักสำหรับรันโปรแกรม Service ---
if __name__ == "__main__":
    path_to_listen = '/schools'
    
    print(f"\n--- [Catch-up] กำลังตรวจสอบข้อมูลที่ค้างอยู่ที่ Path: '{path_to_listen}' ---")
    try:
        all_schools = db.reference(path_to_listen, app=app).get()
        if all_schools:
            pending_count = 0
            for school_name, school_data in all_schools.items():
                students = school_data.get('students', {})
                for student_id, student_data in students.items():
                    photo_data = student_data.get('photoData', {})
                    if isinstance(photo_data, dict) and photo_data.get('photoStatus') == 'processed':
                        pending_count += 1
                        print(f"   - พบงานค้างของ: {school_name}/{student_id}")
                        handle_photo_data(school_name, student_id, photo_data)
            
            if pending_count == 0:
                print("ไม่พบข้อมูลที่ค้างอยู่")
            else:
                print(f"\n--- [Catch-up] ประมวลผลข้อมูลที่ค้างอยู่ {pending_count} รายการเรียบร้อยแล้ว ---")
        else:
            print("ไม่พบข้อมูลโรงเรียน")
    except Exception as e:
        print(f"❌ เกิดข้อผิดพลาดระหว่างการตรวจสอบข้อมูลที่ค้างอยู่: {e}")

    print(f"\n✅ เริ่มการเฝ้าฟัง Path '{path_to_listen}' แบบ Real-time")
    print("(กด Ctrl+C เพื่อหยุด)")
    
    shutdown_event = threading.Event()

    try:
        db.reference(path_to_listen, app=app).listen(listener_callback)
        shutdown_event.wait()
        
    except KeyboardInterrupt:
        print("\nShutting down gracefully...")
    except Exception as e:
        print(f"❌ Listener เกิดข้อผิดพลาดร้ายแรง: {e}")
