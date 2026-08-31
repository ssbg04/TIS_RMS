'use strict';
const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

// ── Embedded images ────────────────────────────────────────────────────────────
// Find the absolute path to the school logo
function getLogoPath() {
    const candidates = [
        // Local copy inside backend (primary — works standalone/deployed)
        path.join(__dirname, '..', '..', 'assets', 'logo.png'),
        // Frontend assets folder (fallback — dev environment)
        path.join(__dirname, '..', '..', '..', 'frontend', 'assets', 'images', 'logo.png'),
    ];
    for (const p of candidates) {
        if (fs.existsSync(p)) return p;
    }
    return null;
}

const LOGO_PATH = getLogoPath();

// ── Transporter ────────────────────────────────────────────────────────────────
let transporter = null;

const getTransporter = () => {
    const user = process.env.SMTP_USER ? process.env.SMTP_USER.trim() : null;
    const rawPass = process.env.SMTP_PASS ? process.env.SMTP_PASS.trim() : null;
    const pass = rawPass ? rawPass.replace(/\s+/g, '') : null;

    if (!user || !pass) {
        console.log('[EmailService] SMTP_USER or SMTP_PASS not set. Emails will be logged to console in dev mode.');
        return null;
    }

    transporter = nodemailer.createTransport({
        host: 'smtp.gmail.com',
        port: 465,
        secure: true,
        auth: { user, pass },
    });

    return transporter;
};

// ── Shared layout helpers ──────────────────────────────────────────────────────
const YEAR = new Date().getFullYear();

const headerLogo = LOGO_PATH
    ? `<img src="cid:school-logo" alt="Talisay Integrated School" width="72" height="72" style="display:block;margin:0 auto 12px;border-radius:50%;border:3px solid rgba(255,255,255,0.3);">`
    : '';

function emailShell(bodyContent) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TIS Record Management System</title>
</head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:32px 0;">
  <tr><td align="center">
    <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

      <!-- HEADER -->
      <tr>
        <td style="background:linear-gradient(160deg,#14532d 0%,#166534 60%,#15803d 100%);padding:36px 32px 28px;text-align:center;">
          ${headerLogo}
          <div style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.3px;line-height:1.2;">Talisay Integrated School</div>
          <div style="color:rgba(255,255,255,0.75);font-size:12px;margin-top:4px;letter-spacing:0.5px;text-transform:uppercase;">Record Management System</div>
        </td>
      </tr>

      <!-- BODY -->
      <tr><td style="padding:36px 36px 28px;">${bodyContent}</td></tr>

      <!-- FOOTER -->
      <tr>
        <td style="background:#f8fafc;border-top:1px solid #e2e8f0;padding:20px 32px;text-align:center;">
          <p style="margin:0;font-size:11px;color:#94a3b8;line-height:1.7;">
            &copy; ${YEAR} Talisay Integrated School &mdash; Tiaong, Quezon<br>
            This is an automated message from the TIS Record Management System.<br>
            Please do not reply to this email.
          </p>
        </td>
      </tr>

    </table>
  </td></tr>
</table>
</body>
</html>`;
}

// ── OTP Email ──────────────────────────────────────────────────────────────────

/**
 * Sends a 6-digit password reset OTP to the user's email.
 */
const sendPasswordResetOtp = async ({ to, username, otp }) => {
    const mailTransporter = getTransporter();
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    // Render OTP digits as individual styled boxes
    const digitBoxes = otp.toString().split('').map(d =>
        `<span style="display:inline-block;width:40px;height:52px;line-height:52px;margin:0 4px;background:#f0fdf4;border:2px solid #16a34a;border-radius:10px;font-size:28px;font-weight:800;color:#14532d;text-align:center;font-family:'Courier New',Courier,monospace;">${d}</span>`
    ).join('');

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Hello, <span style="color:#15803d;">@${username}</span></p>
      <p style="margin:0 0 28px;font-size:14px;color:#475569;line-height:1.7;">
        We received a request to reset the password on your TIS RMS account.
        Use the verification code below to continue. <strong>Do not share this code with anyone.</strong>
      </p>

      <!-- OTP Digits -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:8px 0 24px;">
        ${digitBoxes}
      </td></tr></table>

      <!-- Expiry pill -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding-bottom:28px;">
        <span style="display:inline-block;background:#fef9c3;border:1px solid #fde047;color:#713f12;font-size:12px;font-weight:600;padding:6px 16px;border-radius:999px;">
          &#9201; Expires in <strong>10 minutes</strong>
        </span>
      </td></tr></table>

      <!-- Divider -->
      <hr style="border:none;border-top:1px solid #e2e8f0;margin:0 0 20px;">

      <!-- Security notice -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr>
        <td width="4" style="background:#f59e0b;border-radius:4px;">&nbsp;</td>
        <td style="padding:10px 14px;font-size:12px;color:#78350f;background:#fffbeb;border-radius:0 8px 8px 0;">
          <strong>Security Notice:</strong> If you did not request this, please ignore this email or contact your system administrator immediately. Your password will remain unchanged.
        </td>
      </tr></table>
    `;

    const htmlContent = emailShell(body);

    if (!mailTransporter) {
        console.log(`\n======================================================`);
        console.log(`[EmailService DEV] PASSWORD RESET OTP FOR @${username}`);
        console.log(`To: ${to}`);
        console.log(`OTP Code: ${otp}`);
        console.log(`Expires in: 10 minutes`);
        console.log(`======================================================\n`);
        return { success: true, mode: 'dev-console' };
    }

    try {
        const mailOptions = {
            from: fromAddress,
            to,
            subject: `[TIS RMS] Your password reset code: ${otp}`,
            html: htmlContent,
            text: `Hello @${username},\n\nYour TIS RMS password reset code is: ${otp}\n\nThis code expires in 10 minutes.\n\nIf you did not request this, contact your administrator.`,
        };
        
        if (LOGO_PATH) {
            mailOptions.attachments = [{
                filename: 'logo.png',
                path: LOGO_PATH,
                cid: 'school-logo' // same cid value as in the html img src
            }];
        }

        const info = await mailTransporter.sendMail(mailOptions);
        console.log(`[EmailService] OTP sent to ${to} (${info.messageId})`);
        return { success: true, messageId: info.messageId };
    } catch (err) {
        console.error(`[EmailService] Failed to send OTP to ${to}:`, err.message);
        throw new Error(`Failed to send email OTP: ${err.message}`);
    }
};

// ── Reset Link Email ───────────────────────────────────────────────────────────

/**
 * Sends a password reset link to the user's email.
 */
const sendPasswordResetLink = async ({ to, username, resetLink, expiresMinutes = 15 }) => {
    const mailTransporter = getTransporter();
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Hello, <span style="color:#15803d;">@${username}</span></p>
      <p style="margin:0 0 28px;font-size:14px;color:#475569;line-height:1.7;">
        An administrator has initiated a password reset for your TIS RMS account.
        Click the button below to set a new password. This link is single-use and will expire after
        <strong>${expiresMinutes} minutes</strong>.
      </p>

      <!-- CTA Button -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:4px 0 28px;">
        <a href="${resetLink}" target="_blank"
           style="display:inline-block;background:#15803d;color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;padding:14px 40px;border-radius:10px;letter-spacing:0.3px;box-shadow:0 4px 14px rgba(21,128,61,0.4);">
          &#128273;&nbsp; Reset My Password
        </a>
      </td></tr></table>

      <!-- Expiry pill -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding-bottom:24px;">
        <span style="display:inline-block;background:#fef9c3;border:1px solid #fde047;color:#713f12;font-size:12px;font-weight:600;padding:6px 16px;border-radius:999px;">
          &#9201; Link expires in <strong>${expiresMinutes} minutes</strong>
        </span>
      </td></tr></table>

      <!-- Fallback link -->
      <p style="margin:0 0 6px;font-size:12px;color:#64748b;">If the button doesn't work, copy and paste this link into your browser:</p>
      <p style="margin:0 0 24px;font-size:12px;word-break:break-all;">
        <a href="${resetLink}" style="color:#15803d;text-decoration:underline;">${resetLink}</a>
      </p>

      <!-- Divider -->
      <hr style="border:none;border-top:1px solid #e2e8f0;margin:0 0 20px;">

      <!-- Security notice -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr>
        <td width="4" style="background:#94a3b8;border-radius:4px;">&nbsp;</td>
        <td style="padding:10px 14px;font-size:12px;color:#475569;background:#f8fafc;border-radius:0 8px 8px 0;">
          <strong>Security Notice:</strong> If you did not expect this email, please disregard it or contact your system administrator. Your password will not change unless you click the link above.
        </td>
      </tr></table>
    `;

    const htmlContent = emailShell(body);

    if (!mailTransporter) {
        console.log(`\n======================================================`);
        console.log(`[EmailService DEV] PASSWORD RESET LINK FOR @${username}`);
        console.log(`To: ${to}`);
        console.log(`Reset Link: ${resetLink}`);
        console.log(`Expires in: ${expiresMinutes} minutes`);
        console.log(`======================================================\n`);
        return { success: true, mode: 'dev-console' };
    }

    try {
        const mailOptions = {
            from: fromAddress,
            to,
            subject: `[TIS RMS] Password reset link for @${username}`,
            html: htmlContent,
            text: `Hello @${username},\n\nAn administrator requested a password reset for your TIS RMS account.\n\nReset link:\n${resetLink}\n\nThis link expires in ${expiresMinutes} minutes.\n\nIf you did not request this, contact your administrator.`,
        };

        if (LOGO_PATH) {
            mailOptions.attachments = [{
                filename: 'logo.png',
                path: LOGO_PATH,
                cid: 'school-logo'
            }];
        }

        const info = await mailTransporter.sendMail(mailOptions);
        console.log(`[EmailService] Reset link sent to ${to} (${info.messageId})`);
        return { success: true, messageId: info.messageId };
    } catch (err) {
        console.error(`[EmailService] Failed to send reset link to ${to}:`, err.message);
        throw new Error(`Failed to send email link: ${err.message}`);
    }
};

module.exports = {
    sendPasswordResetOtp,
    sendPasswordResetLink,
};
