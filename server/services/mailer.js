const nodemailer = require('nodemailer');

function isBlank(value) {
  return typeof value !== 'string' || value.trim().length === 0;
}

function createTransporter() {
  const provider = (process.env.MAIL_PROVIDER || 'gmail').toLowerCase();

  if (provider === 'console') {
    return null;
  }

  if (provider === 'mailtrap') {
    if (isBlank(process.env.MAILTRAP_USER) || isBlank(process.env.MAILTRAP_PASS)) {
      if (process.env.NODE_ENV !== 'production') {
        return null;
      }
      throw new Error(
        'EMAIL_CONFIG_MISSING: Vui long cau hinh MAILTRAP_USER va MAILTRAP_PASS trong server/.env',
      );
    }

    return nodemailer.createTransport({
      host: process.env.MAILTRAP_HOST || 'sandbox.smtp.mailtrap.io',
      port: Number(process.env.MAILTRAP_PORT || 2525),
      secure: false,
      auth: {
        user: process.env.MAILTRAP_USER,
        pass: process.env.MAILTRAP_PASS,
      },
    });
  }

  if (isBlank(process.env.MAIL_USER) || isBlank(process.env.MAIL_PASS)) {
    if (process.env.NODE_ENV !== 'production') {
      return null;
    }
    throw new Error(
      'EMAIL_CONFIG_MISSING: Vui long cau hinh MAIL_USER va MAIL_PASS (Gmail App Password) trong server/.env',
    );
  }

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.MAIL_USER,
      pass: process.env.MAIL_PASS,
    },
  });
}

async function sendMail({ to, subject, text, html }) {
  const provider = (process.env.MAIL_PROVIDER || 'gmail').toLowerCase();
  const transporter = createTransporter();
  const from = process.env.MAIL_FROM || process.env.MAIL_USER || 'no-reply@healthylife.local';

  if (!transporter) {
    console.log('==== OTP MAIL (CONSOLE MODE) ====');
    console.log('Provider:', provider);
    console.log('To:', to);
    console.log('Subject:', subject);
    if (text) {
      console.log('Text:', text);
    }
    console.log('=================================');

    return { accepted: [to], response: 'console-mode' };
  }

  return transporter.sendMail({
    from,
    to,
    subject,
    text,
    html,
  });
}

module.exports = {
  sendMail,
};
