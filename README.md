# n8n Installer

یک اسکریپت ساده و تمام‌خودکار برای نصب یا حذف `n8n` بر روی سرور لینوکسی شما با پشتیبانی از Docker، Docker Compose و دامنه با SSL رایگان (Let's Encrypt) از طریق Traefik.

## ویژگی‌ها

- نصب خودکار Docker و Docker Compose (در صورت نیاز)
- پشتیبانی کامل از دامنه + SSL (Let's Encrypt)
- رابط تعاملی ساده برای نصب یا حذف n8n
- قابلیت اجرا روی IP یا دامنه
- قابلیت بروز رسانی 

## نصب سریع

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xpersian/n8n-installer/main/n8n.sh)
```
<img width="459" height="232" alt="image" src="https://github.com/user-attachments/assets/9ef12c94-4ec8-4eb4-94d1-d0b9d3e3c8da" />


## پیش‌نیازها

- سیستم عامل Ubuntu و سایر توزیع ها 
- دسترسی به `root` یا `sudo`
- دامنه معتبر (اختیاری، برای SSL )

## آدرس دسترسی

- اگر دامنه وارد کرده باشید:
  ```
  https://your-domain.com
  ```

- اگر دامنه وارد نکرده باشید:
  ```
  http://your-server-ip:5678
  ```

## حذف کامل n8n

برای حذف کامل، اسکریپت را دوباره اجرا کرده و گزینه ۲ را انتخاب کنید. این عملیات شامل:

- توقف و حذف کانتینرهای n8n
- حذف کامل دایرکتوری نصب n8n (`n8n-docker/`)

---
 بعد از نصب از طریق لینک ها وارد صفحه ی لاگین بشید و اکانت ادمین رو بسازید از طریق بخش setting  و users میتونید کاربر جدید با email تعریف کنید. 
## سورس کد n8n

GitHub: [https://github.com/n8n-io/n8n](https://github.com/n8n-io/n8n)
