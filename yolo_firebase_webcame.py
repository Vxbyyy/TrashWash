import cv2
import time
import firebase_admin
from firebase_admin import credentials, db
from ultralytics import YOLO

# ================= FIREBASE =================
cred = credential  s.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    "databaseURL": "https://smart-trash-app-2af97-default-rtdb.asia-southeast1.firebasedatabase.app/"
})

ref = db.reference("/deteksi")

# ================= YOLO =================
model = YOLO("best.pt")
print("CLASS MODEL:", model.names)

cap = cv2.VideoCapture(0)

last_send = 0
last_hasil = "Tidak Ada"

print("📷 Webcam aktif - deteksi stabil")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    results = model(frame, conf=0.5)

    best_conf = 0
    best_label = None
    best_box = None

    # ===== PILIH DETEKSI TERKUAT =====
    for r in results:
        for box in r.boxes:
            conf = float(box.conf[0])
            cls = int(box.cls[0])

            if conf > best_conf:
                best_conf = conf
                best_label = model.names[cls]
                best_box = box

    # ===== JIKA ADA DETEKSI =====
    if best_label:
        label = best_label.lower()

        if "non" in label:
            hasil = "Non-Organik"
        elif "organik" in label:
            hasil = "Organik"
        else:
            hasil = "Tidak Ada"

    else:
        hasil = "Tidak Ada"

    # ===== KIRIM KE FIREBASE (STABIL) =====
    if hasil != last_hasil and time.time() - last_send > 1:
        ref.set({"hasil": hasil})
        print("🔥 Firebase:", hasil)
        last_hasil = hasil
        last_send = time.time()

    # ===== DRAW BOX =====
    if best_box and hasil != "Tidak Ada":
        x1, y1, x2, y2 = map(int, best_box.xyxy[0])
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(
            frame,
            f"{hasil} ({best_conf:.2f})",
            (x1, y1 - 10),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (0, 255, 0),
            2
        )

    cv2.imshow("YOLO → Firebase → Servo", frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
