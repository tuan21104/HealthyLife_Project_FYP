# HealthyLife Mobile Application 🍏

## Overview
HealthyLife is a comprehensive, full-stack health and lifestyle management application developed as a Final Year Project for COMP1682 at the University of Greenwich. It uniquely integrates nutritional tracking, financial management (calorie-budget e-commerce), and context-aware AI coaching to provide holistic, personalized lifestyle guidance.

**Supervisor:** Dr. Doãn Trung Tùng  
**Developer:** Phan Anh Tuấn

## Tech Stack
* **Frontend:** Flutter (Dart)
* **Backend:** Node.js, Express.js
* **Database:** MongoDB & Mongoose
* **AI Integration:** Google Gemini API
* **Other Services:** Firebase Cloud Messaging (FCM) for push notifications, JSON Web Tokens (JWT) for secure authentication.

## Core Features
* **AI Coaching:** Context-orchestrated LLM inference pipeline using Gemini API.
* **Smart E-commerce:** Calorie budget validation logic during checkout.
* **Hybrid Diary Sync:** Cloud-first, cache-first fallback with user-scoped data isolation.
* **Expense Tracking:** Adaptive anomaly detection and automated push notifications.
* **Interactive Dashboard:** Concurrent multi-metric data visualization using `fl_chart`.

---

## 🛠️ Prerequisites
Before running this project, please ensure you have the following installed:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.x or higher)
* [Node.js](https://nodejs.org/) (Version 18.x or higher)
* A running instance of MongoDB (Local or MongoDB Atlas)

---

## 🚀 Installation & Setup

### 1. Backend Setup (Node.js/Express)
Navigate to the server directory and install dependencies:
```bash
cd server
npm install