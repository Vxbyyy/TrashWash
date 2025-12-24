import cv2
from ultralytics import YOLO
from firebase_admin import db
import firebase_config  # WAJIB

model = YOLO("best.pt")
cap = cv2.VideoCapture(0)

while True:
    ret, frame = cap.read()
    if not ret:
        break

    results = model(frame)

    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            conf = float(box.conf[0])

            data = {
                "class": cls,
                "confidence": conf
            }

            db.reference("deteksi").push(data)

    cv2.imshow("YOLO Webcam", frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
