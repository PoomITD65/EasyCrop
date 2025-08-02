import os
import json
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, status, Response, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from firebase_admin import auth, db
import httpx

# นำเข้าโมเดล UserPublic ที่ถูกต้อง
from model.user import UserPublic 

# ตั้งค่า Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

router = APIRouter()
bearer_scheme = HTTPBearer()

# ==============================================================================
# 1. ฟังก์ชันสำหรับบันทึก Log กิจกรรม
# ==============================================================================
def log_user_activity(user: UserPublic, action: str, details: dict = None):
    """ฟังก์ชันกลางสำหรับบันทึกกิจกรรมของผู้ใช้ลง Firebase RTDB"""
    try:
        uid = user.id
        log_entry = {
            "timestamp": {".sv": "timestamp"},
            "action": action,
            "details": details or {}
        }
        db.reference(f'activity_logs/{uid}').push(log_entry)
        logging.info(f"Activity logged for user '{user.username}' (UID: {uid}): {action}")
    except Exception as e:
        logging.error(f"Failed to log activity for user '{user.username}': {e}")


# ==============================================================================
# 2. Dependency สำหรับตรวจสอบสิทธิ์และดึงข้อมูลผู้ใช้
# ==============================================================================
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)) -> UserPublic:
    token = credentials.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token['uid']
        
        user_ref = db.reference(f'accounts/{uid}')
        user_data = user_ref.get()

        if not user_data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found in database.")
        
        return UserPublic(id=uid, **user_data)
        
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except auth.InvalidIdTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logging.error(f"Authentication check failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not validate credentials.",
        )

# ==============================================================================
# Pydantic Models
# ==============================================================================
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    emailOrUsername: str
    password: str

class TokenResponse(BaseModel):
    message: str
    access_token: str
    token_type: str
    uid: str

class UserUpdate(BaseModel):
    username: str

class PasswordChange(BaseModel):
    current_password: str
    new_password: str

# ==============================================================================
# Helper function
# ==============================================================================
def _get_user_info_from_rtdb(identifier: str):
    users_ref = db.reference('accounts')
    if "@" in identifier:
        query = users_ref.order_by_child('email').equal_to(identifier)
    else:
        query = users_ref.order_by_child('username').equal_to(identifier)
    
    snapshot = query.get()
    if not snapshot:
        return None, None, None
        
    user_uid = list(snapshot.keys())[0]
    user_data = snapshot[user_uid]
    email = user_data.get('email')
    return user_uid, email, user_data

# ==============================================================================
# Endpoints
# ==============================================================================

@router.post("/auth/register", response_model=UserPublic, status_code=status.HTTP_201_CREATED)
async def register_user(user_in: UserCreate):
    logging.info(f"Attempting to register user: username='{user_in.username}', email='{user_in.email}'")
    users_ref = db.reference('accounts')
    if users_ref.order_by_child('username').equal_to(user_in.username).get():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already exists.")
    
    new_user_uid = None
    try:
        new_user = auth.create_user(email=user_in.email, password=user_in.password, email_verified=False)
        new_user_uid = new_user.uid
    except auth.AuthError as e:
        detail_msg = "Failed to create user."
        if "EMAIL_EXISTS" in str(e):
            detail_msg = "Email address is already in use."
        elif "WEAK_PASSWORD" in str(e):
            detail_msg = "Password must be at least 6 characters."
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail_msg)
    
    try:
        today = datetime.now()
        date_key = today.strftime('%Y%m%d')
        counter_ref = db.reference(f'counters/{date_key}')
        
        def increment_counter(current_data):
            return (current_data or 0) + 1
        
        transaction_result = counter_ref.transaction(increment_counter)
        new_count = transaction_result if transaction_result is not None else (counter_ref.get() or 0)

        display_date = today.strftime('%d%m%Y')
        custom_format_id = f'{display_date}{str(new_count).zfill(3)}'
        
        user_data = {
            'customId': custom_format_id,
            'username': user_in.username,
            'email': user_in.email,
            'createdAt': int(datetime.now().timestamp() * 1000),
            'loginAttempts': {'failedCount': 0, 'isPermanentlyLocked': False, 'lockoutUntil': 0}
        }
        users_ref.child(new_user_uid).set(user_data)
        return UserPublic(id=new_user_uid, **user_data)
    except Exception as e:
        if new_user_uid:
            auth.delete_user(new_user_uid)
        logging.error(f"RTDB user profile creation failed: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not create user profile in the database.")

@router.post("/auth/login", response_model=TokenResponse)
async def login_user(user_in: UserLogin):
    identifier = user_in.emailOrUsername
    password = user_in.password
    user_uid, user_email, user_data = _get_user_info_from_rtdb(identifier)

    if not user_uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ไม่พบชื่อผู้ใช้งานนี้ในระบบ")

    login_attempts_ref = db.reference(f'accounts/{user_uid}/loginAttempts')
    attempts_data = user_data.get('loginAttempts', {})
    
    if attempts_data.get('isPermanentlyLocked'):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="บัญชีนี้ถูกล็อคถาวร กรุณาติดต่อ Support")
    
    lockout_until = attempts_data.get('lockoutUntil', 0)
    if datetime.now().timestamp() * 1000 < lockout_until:
        remaining_minutes = int((lockout_until - datetime.now().timestamp() * 1000) / 60000) + 1
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"บัญชีถูกล็อคชั่วคราว กรุณาลองใหม่อีกครั้งใน {remaining_minutes} นาที")

    firebase_web_api_key = os.getenv("FIREBASE_WEB_API_KEY")
    firebase_sign_in_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={firebase_web_api_key}"

    # try:
    async with httpx.AsyncClient() as client:
        response = await client.post(firebase_sign_in_url, json={"email": user_email, "password": password, "returnSecureToken": True})

    if response.status_code == 200:
        login_attempts_ref.set({'failedCount': 0, 'isPermanentlyLocked': False, 'lockoutUntil': 0})
        
        custom_token = auth.create_custom_token(user_uid)
        
        return TokenResponse(message="Login successful", access_token=custom_token.decode('utf-8'), uid=user_uid, token_type="Bearer")
    elif response.status_code == 400:
        failed_count = attempts_data.get('failedCount', 0) + 1
        updates = {'failedCount': failed_count}
        lockout_minutes = 0
        
        if failed_count >= 25:
            updates['isPermanentlyLocked'] = True
        elif failed_count in [5, 10, 15, 20]:
            lockout_map = {5: 5, 10: 10, 15: 30, 20: 60}
            lockout_minutes = lockout_map[failed_count]
            updates['lockoutUntil'] = (datetime.now() + timedelta(minutes=lockout_minutes)).timestamp() * 1000
        
        login_attempts_ref.update(updates)

        if updates.get('isPermanentlyLocked'):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="รหัสผ่านไม่ถูกต้อง บัญชีนี้ถูกล็อคถาวร")
        if lockout_minutes > 0:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"รหัสผ่านไม่ถูกต้อง บัญชีถูกล็อคชั่วคราว {lockout_minutes} นาที")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="รหัสผ่านไม่ถูกต้อง")
    else: 
        logging.error(f"Firebase Auth error: {response.text}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="เกิดข้อผิดพลาดกับ Server")
    # except Exception as e:
    #     print("eeeeeeeeeeeeeeeeeeeeee", e)
    #     logging.error(f"Login process error for '{identifier}': {e}", exc_info=True)
    #     raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์")

@router.put("/users/me", response_model=UserPublic)
async def update_user_profile(user_update: UserUpdate, current_user: UserPublic = Depends(get_current_user)):
    uid = current_user.id
    new_username = user_update.username.strip()
    if not new_username:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username cannot be empty.")
    
    user_ref = db.reference(f'accounts/{uid}')
    
    if current_user.username == new_username:
        return current_user

    accounts_ref = db.reference('accounts')
    existing_user_query = accounts_ref.order_by_child('username').equal_to(new_username).get()
    if existing_user_query and list(existing_user_query.keys())[0] != uid:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="ชื่อผู้ใช้งานนี้มีคนใช้แล้ว")
            
    try:
        user_ref.update({'username': new_username})
        updated_user = current_user.copy(update={'username': new_username})
        log_user_activity(updated_user, "update_profile", {"new_username": new_username})
        return updated_user
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update profile.")

@router.post("/auth/change-password")
async def change_password(pass_change: PasswordChange, current_user: UserPublic = Depends(get_current_user)):
    uid = current_user.id
    email = current_user.email
    try:
        firebase_web_api_key = os.getenv("FIREBASE_WEB_API_KEY")
        firebase_sign_in_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={firebase_web_api_key}"
        async with httpx.AsyncClient() as client:
            verify_response = await client.post(
                firebase_sign_in_url,
                json={"email": email, "password": pass_change.current_password, "returnSecureToken": False}
            )
        if verify_response.status_code != 200:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="รหัสผ่านปัจจุบันไม่ถูกต้อง")

        auth.update_user(uid, password=pass_change.new_password)
        log_user_activity(current_user, "change_password")
        return {"message": "Password changed successfully."}
    except auth.AuthError as e:
        if "WEAK_PASSWORD" in str(e):
             raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="รหัสผ่านใหม่อ่อนแอเกินไป")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="เกิดข้อผิดพลาดกับ Firebase Auth")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="เกิดข้อผิดพลาดไม่ทราบสาเหตุ")

@router.get("/users/me", response_model=UserPublic)
async def get_own_user_data(current_user: UserPublic = Depends(get_current_user)):
    return current_user

@router.get("/users/{uid}", response_model=UserPublic)
async def get_user_data_by_id(uid: str, current_user: UserPublic = Depends(get_current_user)):
    user_ref = db.reference(f'accounts/{uid}')
    user_data = user_ref.get()
    if not user_data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return UserPublic(id=uid, **user_data)