import cv2
import time
import firebase_admin
from firebase_admin import credentials, db
from ultralytics import YOLO

# --- 1. KONFIGURASI FIREBASE ---
cred = credentials.Certificate("firebase_key.json")
firebase_admin.initialize_app(cred, {
    "databaseURL": "https://smart-trash-app-2af97-default-rtdb.asia-southeast1.firebasedatabase.app/"
})
ref = db.reference('deteksi_sampah/jenis_sampah_')

# --- 2. LOAD MODEL YOLOv8 ---
print("[INFO] Meload model YOLOv8...")
model = YOLO("best.pt")  # Pastikan file best.pt ada di folder yang sama
print("[INFO] Model berhasil diload!")

# --- 3. INISIALISASI WEBCAM ---
cap = cv2.VideoCapture(0)
cap.set(3, 640)  # Lebar frame
cap.set(4, 480)  # Tinggi frame

print("[INFO] Mulai deteksi. Tekan 'q' untuk berhenti.")

# Variabel kontrol pengiriman data
last_sent_time = 0
DELAY_SEND = 2.0  # Kirim data tiap 2 detik jika sampah masih sama
last_sent_class = ""

while True:
    ret, frame = cap.read()
    if not ret:
        print("[ERROR] Tidak dapat membaca frame dari webcam.")
        break

    # --- DETEKSI ---
    results = model(frame, conf=0.5, verbose=False)

    # Default values
    jenisOrganik = ""
    jenisNonOrganik = ""
    statusOrganik = ""
    statusNonOrganik = ""
    nama_sampah = "Tidak Terdeteksi"
    confidence_score = 0.0

    if results[0].boxes:
        box = results[0].boxes[0]
        cls_id = int(box.cls[0])
        nama_sampah = model.names[cls_id]
        confidence_score = float(box.conf[0])

        # Visualisasi bounding box
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(frame, f"{nama_sampah} {confidence_score:.2f}", (x1, y1-10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

        # Tentukan kategori
        if nama_sampah.lower() == "organik":
            jenisOrganik = nama_sampah
            statusOrganik = "terdeteksi"
        elif nama_sampah.lower() == "non-organik":
            jenisNonOrganik = nama_sampah
            statusNonOrganik = "terdeteksi"

    # --- LOGIKA PENGIRIMAN KE FIREBASE ---
    current_time = time.time()
    status_berubah = (nama_sampah != last_sent_class)
    waktunya_update = (current_time - last_sent_time > DELAY_SEND)

    if nama_sampah != "Tidak Terdeteksi":
        if status_berubah or waktunya_update:
            data_to_send = {
                "jenisOrganik": jenisOrganik,
                "jenisNonOrganik": jenisNonOrganik,
                "statusOrganik": statusOrganik,
                "statusNonOrganik": statusNonOrganik,
                "confidence": round(confidence_score, 2),
                "timestamp": int(current_time)
            }

            try:
                ref.push(data_to_send)
                print(f"[SENT] Data ke Firebase: {data_to_send}")
                last_sent_class = nama_sampah
                last_sent_time = current_time
            except Exception as e:
                print(f"[ERROR] Gagal push ke Firebase: {e}")

    # Tampilkan webcam
    cv2.imshow("YOLOv8 Trash Detection", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        print("[INFO] Deteksi dihentikan.")
        break

cap.release()
cv2.destroyAllWindows()
