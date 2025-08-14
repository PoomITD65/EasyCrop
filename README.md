# Project Documentation

## 📝 ภาพรวมโปรเจกต์ (Project Overview)

โปรเจกต์นี้คือระบบแอปพลิเคชันสำหรับจัดการข้อมูล ประกอบด้วย 2 ส่วนหลัก:
1.  **Backend (API):** สร้างด้วย **FastAPI (Python)** ทำหน้าที่เชื่อมต่อกับฐานข้อมูล, จัดการตรรกะทางธุรกิจ, ระบบยืนยันตัวตน, และบริการประมวลผลภาพ
2.  **Frontend (Mobile Application):** สร้างด้วย **Flutter** สำหรับให้ผู้ใช้โต้ตอบกับข้อมูลผ่านมือถือ

## ✨ ฟีเจอร์หลัก (Key Features)

-   **ระบบยืนยันตัวตน (Authentication):**
    -   รองรับการสมัครสมาชิกและเข้าสู่ระบบด้วย Email/Username และ Password ผ่าน **Firebase Authentication**
    -   Backend มีระบบป้องกันการ Brute-force attack โดยการล็อคบัญชี

-   **การจัดการข้อมูลหลัก (Core Data Management):**
    -   Backend มี API สำหรับการสร้าง, อ่าน, แก้ไข, และลบ (CRUD) ข้อมูลโรงเรียน (Schools) และข้อมูลนักเรียน (Students)
    -   แอปพลิเคชันฝั่ง Mobile สามารถแสดงผลและจัดการข้อมูลโรงเรียนและนักเรียนได้ตามสิทธิ์ของผู้ใช้

-   **บริการประมวลผลภาพถ่าย (Image Processing Service):**
    -   Backend มี API สำหรับรับภาพถ่ายนักเรียนและทำการประมวลผล (เช่น ปรับขนาด, ตรวจสอบคุณภาพ)
    -   แอปพลิเคชันฝั่ง Mobile สามารถอัปโหลดภาพเพื่อให้ Backend ประมวลผลได้

-   **ระบบบันทึกกิจกรรมเบื้องหลัง (Backend Activity Logging):**
    -   Backend มีระบบบันทึกกิจกรรมที่สำคัญของผู้ใช้ทั้งหมดลงในฐานข้อมูลโดยอัตโนมัติเพื่อการตรวจสอบความปลอดภัย

## 🛠️ เทคโนโลยีที่ใช้ (Tech Stack)

**Backend (FastAPI):**
-   **Framework:** FastAPI
-   **Language:** Python 3.11+
-   **Database:** Firebase Realtime Database
-   **Authentication:** Firebase Admin SDK
-   **Server:** Uvicorn

**Frontend (Flutter):**
-   **Framework:** Flutter 3+
-   **Language:** Dart
-   **State Management:** (ระบุ State Management ที่ใช้ เช่น Provider, BLoC, Riverpod)
-   **Authentication:** firebase_auth (Firebase SDK for Flutter)

---

## 🚀 การติดตั้งและเริ่มใช้งาน (Setup and Run)

### Backend (FastAPI)

1.  **Clone a repository:**
    ```bash
    git clone <your-repository-url>
    cd Backend
    ```
2.  **สร้างและเปิดใช้งาน Virtual Environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate  # บน Mac/Linux
    venv\Scripts\activate    # บน Windows
    ```
3.  **ติดตั้ง Dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
4.  **ตั้งค่า Environment Variables:**
    -   สร้างไฟล์ `.env` ในโฟลเดอร์ `Backend`
    -   เพิ่มค่า `FIREBASE_WEB_API_KEY="<your_firebase_web_api_key>"`
    -   **(สำคัญ)** ดาวน์โหลดไฟล์ **Service Account Key** (JSON) จาก Firebase Console และตั้งค่า Path ให้ถูกต้องในโค้ดที่ทำการ `initialize_app()`

5.  **รัน Server:**
    ```bash
    uvicorn main:app --reload
    ```
    API จะพร้อมใช้งานที่ `http://127.0.0.1:8000`
    
    **รัน Server แบบกำหนด Host:**
    ```bash
    uvicorn main:app --host 192.168.1.32 --reload
    ```
    ตัวอย่าง IP

### Frontend (Flutter)

1.  **ไปยังโฟลเดอร์ Frontend:**
    ```bash
    cd Frontend # หรือชื่อโฟลเดอร์ Flutter ของคุณ
    ```
2.  **ติดตั้ง Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **ตั้งค่า Firebase:**
    -   ทำตามขั้นตอนการตั้งค่า Firebase สำหรับ Flutter โดยใช้ FlutterFire CLI
    -   ตรวจสอบให้แน่ใจว่าไฟล์ `firebase_options.dart` ถูกสร้างขึ้นอย่างถูกต้อง

4.  **รันแอปพลิเคชัน:**
    ```bash
    flutter run
    ```
    แอปพลิเคชันจะถูกติดตั้งและเปิดขึ้นบน Emulator หรืออุปกรณ์ที่เชื่อมต่ออยู่

---

## 📡 API Endpoints

Endpoint ทั้งหมดจะอยู่ภายใต้ prefix `/api`

### Authentication & User Profile
| Method   | Path                          | การป้องกัน     | คำอธิบาย                                           |
| :------- | :---------------------------- | :------------- | :------------------------------------------------- |
| `POST`   | `/auth/login`                 | Public         | เข้าสู่ระบบเพื่อรับ Authentication Token           |
| `POST`   | `/auth/register`              | Public         | สมัครสมาชิกบัญชีผู้ใช้ใหม่                        |
| `GET`    | `/users/me`                   | **User** | ดึงข้อมูลโปรไฟล์ของผู้ใช้ที่ Login อยู่             |
| `PUT`    | `/users/me`                   | **User** | อัปเดต Username ของผู้ใช้ที่ Login อยู่            |
| `POST`   | `/auth/change-password`       | **User** | เปลี่ยนรหัสผ่านของผู้ใช้ที่ Login อยู่             |

### School Management
| Method   | Path                          | การป้องกัน     | คำอธิบาย                                           |
| :------- | :---------------------------- | :------------- | :------------------------------------------------- |
| `GET`    | `/schools`                    | **User** | ดึงข้อมูลโรงเรียนทั้งหมด                          |
| `POST`   | `/schools`                    | **User** | สร้างโรงเรียนใหม่                                  |
| `DELETE` | `/schools/{school_name}`      | **User** | ลบโรงเรียนและข้อมูลทั้งหมดที่เกี่ยวข้อง           |

### Student Management
| Method   | Path                                | การป้องกัน     | คำอธิบาย                                           |
| :------- | :---------------------------------- | :------------- | :------------------------------------------------- |
| `GET`    | `/schools/{school_name}/students/`  | **User** | ดึงข้อมูลนักเรียนทั้งหมดในโรงเรียน (พร้อม Filter) |
| `POST`   | `/schools/{school_name}/students/`  | **User** | สร้างข้อมูลนักเรียนใหม่                            |
| `GET`    | `/schools/{school_name}/students/{id}` | **User** | ดึงข้อมูลนักเรียนรายคน                            |
| `PUT`    | `/schools/{school_name}/students/{id}` | **User** | อัปเดตข้อมูลนักเรียน                             |
| `DELETE` | `/schools/{school_name}/students/{id}` | **User** | ลบข้อมูลนักเรียน                                  |
| `POST`   | `/schools/{school_name}/students/{id}/photo` | **User** | อัปโหลดรูปถ่ายสำหรับนักเรียน                      |
| `POST`   | `/schools/{school_name}/students/upload-csv` | **User** | อัปโหลดรายชื่อนักเรียนจากไฟล์ CSV                 |
| `POST`   | `/schools/{school_name}/students/export-zip` | **User** | Export รูปถ่ายนักเรียนเป็นไฟล์ ZIP                |

### Admin Functions
| Method   | Path                          | การป้องกัน     | คำอธิบาย                                           |
| :------- | :---------------------------- | :------------- | :------------------------------------------------- |
| `GET`    | `/logs/activity`              | **Admin** | ดึงข้อมูล Log กิจกรรมทั้งหมด                   |
| `GET`    | `/users`                      | **Admin** | ดึงรายชื่อผู้ใช้ทั้งหมดในระบบ                 |
| `POST`   | `/users/{uid}/role`           | **Admin** | อัปเดตสิทธิ์ (Role) ของผู้ใช้ที่ระบุ           |
| `DELETE` | `/users/{uid}`                | **Admin** | ลบบัญชีผู้ใช้ที่ระบุ                          |

