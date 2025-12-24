from firebase_config import deteksi_ref
import time

try:
    print("Mencoba koneksi ke Firebase...")

    deteksi_ref.set({
        "hasil": "TEST_KONEKSI"
    })

    time.sleep(1)

    data = deteksi_ref.get()

    print("Data dari Firebase:", data)
    print("✅ Firebase TERHUBUNG dengan sukses!")

except Exception as e:
    print("❌ Firebase GAGAL tersambung")
    print("Error:", e)