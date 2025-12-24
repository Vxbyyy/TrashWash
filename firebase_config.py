import firebase_admin
from firebase_admin import credentials, db

cred = credentials.Certificate("firebase_key.json")

firebase_admin.initialize_app(cred, {
    "databaseURL": "https://smart-trash-app-2af97-default-rtdb.asia-southeast1.firebasedatabase.app"
})
