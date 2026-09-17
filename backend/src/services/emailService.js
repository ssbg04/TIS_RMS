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

// ── Transporter with Pooling & Fallback ───────────────────────────────────────
let primaryTransporter = null;
let fallbackTransporter = null;

const createTransporter = (port, secure) => {
    const user = process.env.SMTP_USER ? process.env.SMTP_USER.trim() : null;
    const rawPass = process.env.SMTP_PASS ? process.env.SMTP_PASS.trim() : null;
    const pass = rawPass ? rawPass.replace(/\s+/g, '') : null;

    if (!user || !pass) {
        return null;
    }

    return nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'smtp.gmail.com',
        port,
        secure,
        pool: true,
        maxConnections: 3,
        connectionTimeout: 10000,
        greetingTimeout: 10000,
        socketTimeout: 15000,
        auth: { user, pass },
    });
};

const getPrimaryTransporter = () => {
    if (!primaryTransporter) {
        const port = parseInt(process.env.SMTP_PORT || '465', 10);
        primaryTransporter = createTransporter(port, port === 465);
    }
    return primaryTransporter;
};

const getFallbackTransporter = () => {
    if (!fallbackTransporter) {
        fallbackTransporter = createTransporter(587, false);
    }
    return fallbackTransporter;
};

const isConfigured = () => {
    const user = process.env.SMTP_USER ? process.env.SMTP_USER.trim() : null;
    const rawPass = process.env.SMTP_PASS ? process.env.SMTP_PASS.trim() : null;
    return !!(user && rawPass);
};

const sendMailWithFallback = async (mailOptions) => {
    if (!isConfigured()) {
        console.log(`\n======================================================`);
        console.log(`[EmailService DEV] Simulated email to: ${mailOptions.to}`);
        console.log(`Subject: ${mailOptions.subject}`);
        console.log(`======================================================\n`);
        return { success: true, mode: 'dev-console' };
    }

    const primary = getPrimaryTransporter();
    try {
        const info = await primary.sendMail(mailOptions);
        console.log(`[EmailService] Mail sent to ${mailOptions.to} (${info.messageId})`);
        return { success: true, messageId: info.messageId };
    } catch (primaryErr) {
        console.warn(`[EmailService] Primary transport failed (${primaryErr.message}). Attempting port 587 fallback...`);
        try {
            const fallback = getFallbackTransporter();
            if (fallback) {
                const info = await fallback.sendMail(mailOptions);
                console.log(`[EmailService] Fallback sent to ${mailOptions.to} (${info.messageId})`);
                return { success: true, messageId: info.messageId, fallbackUsed: true };
            }
        } catch (fallbackErr) {
            console.error('[EmailService] Fallback transport also failed:', fallbackErr.message);
        }
        throw primaryErr;
    }
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
            cid: 'school-logo'
        }];
    }

    try {
        return await sendMailWithFallback(mailOptions);
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

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send reset link to ${to}:`, err.message);
        throw new Error(`Failed to send email link: ${err.message}`);
    }
};

// ── Teacher Attention Reminder Email ──────────────────────────────────────────

/**
 * Sends a list of students needing document attention to their advisory teacher.
 */
const sendTeacherAttentionReminder = async ({ to, teacherName, sectionsWithStudents }) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    let totalStudents = 0;
    let sectionsHtml = '';

    for (const sec of sectionsWithStudents) {
        totalStudents += sec.students.length;
        const rows = sec.students.map(s => `
          <tr style="border-bottom: 1px solid #e2e8f0;">
            <td style="padding: 10px 12px; font-weight: 600; color: #1e293b; font-size: 13px;">
              ${s.name}
            </td>
            <td style="padding: 10px 12px; color: #475569; font-size: 12px; font-family: 'Courier New', Courier, monospace;">
              ${s.lrn || 'N/A'}
            </td>
            <td style="padding: 10px 12px; color: #b91c1c; font-size: 12px; font-weight: 500;">
              ${s.missingDocs.join(', ')}
            </td>
          </tr>
        `).join('');

        sectionsHtml += `
          <div style="margin-bottom: 24px;">
            <div style="background: #f1f5f9; padding: 8px 12px; border-radius: 6px; font-weight: 700; color: #0f172a; font-size: 13px; margin-bottom: 8px;">
              &#128194; Grade ${sec.gradeLevel} - ${sec.sectionName}
              <span style="font-size: 11px; font-weight: normal; color: #64748b; margin-left: 8px;">(${sec.students.length} student${sec.students.length > 1 ? 's' : ''})</span>
            </div>
            <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse: collapse; font-size: 12px; width: 100%;">
              <thead>
                <tr style="background: #f8fafc; border-bottom: 2px solid #cbd5e1; text-align: left; color: #475569;">
                  <th style="padding: 8px 12px; font-size: 11px; text-transform: uppercase;">Student Name</th>
                  <th style="padding: 8px 12px; font-size: 11px; text-transform: uppercase;">LRN</th>
                  <th style="padding: 8px 12px; font-size: 11px; text-transform: uppercase;">Missing Mandatory Requirement(s)</th>
                </tr>
              </thead>
              <tbody>
                ${rows}
              </tbody>
            </table>
          </div>
        `;
    }

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Hello Teacher <span style="color:#15803d;">${teacherName}</span>,</p>
      <p style="margin:0 0 20px;font-size:14px;color:#475569;line-height:1.6;">
        This is an automated advisory reminder from the <strong>TIS Record Management System</strong>.
        The following <strong>${totalStudents} student${totalStudents > 1 ? 's' : ''}</strong> in your advised section${sectionsWithStudents.length > 1 ? 's' : ''} currently have missing mandatory document requirements (&ldquo;Needs Attention&rdquo;):
      </p>

      ${sectionsHtml}

      <div style="background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: 12px 16px; margin: 20px 0;">
        <p style="margin: 0; font-size: 12px; color: #991b1b; line-height: 1.5;">
          <strong>Action Required:</strong> Please coordinate with the concerned students or parents to submit their required documents. You may view and track their document status directly in the TIS RMS advisory portal.
        </p>
      </div>
    `;

    const htmlContent = emailShell(body);

    const mailOptions = {
        from: fromAddress,
        to,
        subject: `[TIS RMS] Advisory Reminder: ${totalStudents} Student${totalStudents > 1 ? 's' : ''} Need Document Attention`,
        html: htmlContent,
        text: `Hello ${teacherName},\n\nYou have ${totalStudents} students with missing mandatory documents in your advised sections. Please log into TIS RMS to review your advisory classes.\n\nThank you.`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = [{
            filename: 'logo.png',
            path: LOGO_PATH,
            cid: 'school-logo'
        }];
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send attention reminder to ${to}:`, err.message);
        throw new Error(`Failed to send reminder email: ${err.message}`);
    }
};

/**
 * Sends welcome email with initial login credentials when an account is created.
 */
const sendAccountCreatedEmail = async ({ to, username, fullName, role, temporaryPassword }) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const displayName = fullName || `@${username}`;
    const roleUpper = (role || 'user').toUpperCase();

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Welcome, <span style="color:#15803d;">${displayName}</span>!</p>
      <p style="margin:0 0 20px;font-size:14px;color:#475569;line-height:1.7;">
        An account has been created for you on the <strong>Talisay Integrated School Record Management System</strong>.
        You can now sign in using the credentials below:
      </p>

      <!-- Credentials Card -->
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;margin:0 0 24px;overflow:hidden;">
        <tr>
          <td style="padding:16px 20px;border-bottom:1px solid #e2e8f0;background:#f1f5f9;">
            <strong style="color:#334155;font-size:13px;text-transform:uppercase;letter-spacing:0.5px;">Your Account Credentials</strong>
          </td>
        </tr>
        <tr>
          <td style="padding:16px 20px;">
            <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;line-height:1.8;">
              <tr>
                <td width="140" style="color:#64748b;font-weight:600;">Username:</td>
                <td style="color:#0f172a;font-weight:700;font-family:'Courier New',Courier,monospace;">${username}</td>
              </tr>
              <tr>
                <td width="140" style="color:#64748b;font-weight:600;">Assigned Role:</td>
                <td style="color:#15803d;font-weight:700;">${roleUpper}</td>
              </tr>
              <tr>
                <td width="140" style="color:#64748b;font-weight:600;">Temporary Password:</td>
                <td style="color:#0f172a;font-weight:700;font-family:'Courier New',Courier,monospace;">${temporaryPassword}</td>
              </tr>
            </table>
          </td>
        </tr>
      </table>

      <!-- First time warning pill -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding-bottom:24px;">
        <span style="display:inline-block;background:#eff6ff;border:1px solid #bfdbfe;color:#1e40af;font-size:12px;font-weight:600;padding:6px 16px;border-radius:999px;">
          &#128274; For security, please change your password immediately upon your first sign-in.
        </span>
      </td></tr></table>

      <hr style="border:none;border-top:1px solid #e2e8f0;margin:0 0 16px;">

      <p style="margin:0;font-size:12px;color:#64748b;line-height:1.6;">
        If you did not expect this account, please contact the school administration immediately.
      </p>
    `;

    const htmlContent = emailShell(body);

    const mailOptions = {
        from: fromAddress,
        to,
        subject: `Welcome to TIS Record Management System - Your Account Details`,
        html: htmlContent,
        text: `Welcome to TIS Record Management System, ${displayName}!\n\nAn account has been created for you:\nUsername: ${username}\nRole: ${roleUpper}\nTemporary Password: ${temporaryPassword}\n\nPlease sign in and change your password upon first login.`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = [{
            filename: 'logo.png',
            path: LOGO_PATH,
            cid: 'school-logo'
        }];
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send account creation email to ${to}:`, err.message);
        throw new Error(`Failed to send account creation email: ${err.message}`);
    }
};

/**
 * Sends an email notification when a user account is activated or deactivated.
 */
const sendAccountStatusEmail = async ({ to, username, fullName, role, isActive }) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const displayName = fullName || `@${username}`;
    const statusLabel = isActive ? 'Activated' : 'Deactivated';
    const statusColor = isActive ? '#15803d' : '#b91c1c';
    const statusBg = isActive ? '#f0fdf4' : '#fef2f2';
    const statusBorder = isActive ? '#bbf7d0' : '#fecaca';

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Hello, <span style="color:#0f172a;">${displayName}</span></p>
      
      <!-- Status Badge -->
      <div style="margin:16px 0 20px;padding:14px 18px;background:${statusBg};border:1px solid ${statusBorder};border-radius:10px;">
        <div style="font-size:15px;font-weight:700;color:${statusColor};margin-bottom:4px;">
          Account Status: ${statusLabel}
        </div>
        <p style="margin:0;font-size:13px;color:#334155;line-height:1.6;">
          ${isActive 
            ? 'Your account has been <strong>activated</strong> by an administrator. You can now log into the TIS Record Management System and access school records according to your role.'
            : 'Your account has been <strong>deactivated</strong> by an administrator. Your active sessions have been revoked and system access has been suspended.'
          }
        </p>
      </div>

      <p style="margin:0 0 16px;font-size:13px;color:#64748b;line-height:1.6;">
        ${isActive
            ? 'If you have forgotten your password, you can use the "Forgot Password" option on the sign-in screen.'
            : 'If you believe this status change was made in error, please contact your school administrator or ICT coordinator.'
        }
      </p>

      <hr style="border:none;border-top:1px solid #e2e8f0;margin:0 0 16px;">

      <p style="margin:0;font-size:11.5px;color:#94a3b8;line-height:1.6;">
        Account Username: <strong>${username}</strong> | Role: <strong>${(role || 'user').toUpperCase()}</strong>
      </p>
    `;

    const htmlContent = emailShell(body);

    const mailOptions = {
        from: fromAddress,
        to,
        subject: `[TIS RMS] Account ${statusLabel}: Your Account Has Been ${statusLabel}`,
        html: htmlContent,
        text: `Hello ${displayName},\n\nYour TIS Record Management System account has been ${statusLabel.toLowerCase()} by an administrator.\n\n${isActive ? 'You may now log in to the system.' : 'Your access has been suspended. Please contact the administrator if this was in error.'}`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = [{
            filename: 'logo.png',
            path: LOGO_PATH,
            cid: 'school-logo'
        }];
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send account status email to ${to}:`, err.message);
        throw new Error(`Failed to send account status email: ${err.message}`);
    }
};

/**
 * Sends an account deletion confirmation email with a verification link.
 */
const sendAccountDeletionEmail = async ({ to, username, deleteLink, expiresMinutes = 15 }) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Account Deletion Request</p>
      <p style="margin:0 0 20px;font-size:14px;color:#475569;line-height:1.7;">
        Hello, <strong style="color:#0f172a;">@${username}</strong>. We received a request to permanently delete your account on the
        <strong>Talisay Integrated School Record Management System</strong>.
      </p>

      <!-- Danger Warning Badge -->
      <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
        <tr>
          <td style="background:#fef2f2;border:1px solid #fecaca;border-radius:10px;padding:14px 18px;">
            <div style="font-size:14px;font-weight:700;color:#b91c1c;margin-bottom:4px;">
              &#9888; Warning: This action is permanent and irreversible
            </div>
            <p style="margin:0;font-size:13px;color:#7f1d1d;line-height:1.6;">
              Once confirmed, your account credentials will be permanently removed. You will immediately lose access to the system.
            </p>
          </td>
        </tr>
      </table>

      <!-- CTA Button -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:4px 0 24px;">
        <a href="${deleteLink}" target="_blank"
           style="display:inline-block;background:#dc2626;color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;padding:14px 36px;border-radius:10px;letter-spacing:0.3px;box-shadow:0 4px 14px rgba(220,38,38,0.35);">
          &#128465;&nbsp; Confirm &amp; Delete My Account
        </a>
      </td></tr></table>

      <!-- Expiry pill -->
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding-bottom:24px;">
        <span style="display:inline-block;background:#fef9c3;border:1px solid #fde047;color:#713f12;font-size:12px;font-weight:600;padding:6px 16px;border-radius:999px;">
          &#9201; Link expires in <strong>${expiresMinutes} minutes</strong>
        </span>
      </td></tr></table>

      <hr style="border:none;border-top:1px solid #e2e8f0;margin:0 0 16px;">

      <p style="margin:0 0 8px;font-size:12px;color:#64748b;line-height:1.6;">
        If you did not request to delete your account, please ignore this email or change your password immediately. Your account will remain secure.
      </p>
      <p style="margin:0;font-size:11px;color:#94a3b8;word-break:break-all;">
        Or copy and paste this link in your browser:<br>
        <a href="${deleteLink}" style="color:#dc2626;text-decoration:underline;">${deleteLink}</a>
      </p>
    `;

    const htmlContent = emailShell(body);

    const mailOptions = {
        from: fromAddress,
        to,
        subject: `[TIS RMS] Confirm Account Deletion - Action Required`,
        html: htmlContent,
        text: `Hello @${username},\n\nWe received a request to permanently delete your TIS RMS account.\n\nTo confirm, click the link below within ${expiresMinutes} minutes:\n${deleteLink}\n\nIf you did not request this, please ignore this email.`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = [{
            filename: 'logo.png',
            path: LOGO_PATH,
            cid: 'school-logo'
        }];
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send account deletion email to ${to}:`, err.message);
        throw new Error(`Failed to send account deletion email: ${err.message}`);
    }
};

const sendDocumentPickupEmail = async ({ to, studentName, documentNames, pickupDate, message }) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const docList = Array.isArray(documentNames) ? documentNames : [documentNames];
    const docItems = docList
        .map(d => `<li style="margin-bottom:6px;color:#1e293b;font-weight:600;">${d}</li>`)
        .join('');

    const formattedDate = pickupDate || 'Next School Day';

    const customMsgBlock = message && message.trim() ? `
      <div style="margin:20px 0;padding:14px 18px;background:#f8fafc;border-left:4px solid #16a34a;border-radius:6px;font-size:13px;color:#334155;line-height:1.6;">
        <strong>Note from Office:</strong><br>
        ${message.trim().replace(/\n/g, '<br>')}
      </div>
    ` : '';

    const body = `
      <p style="margin:0 0 6px;font-size:16px;font-weight:700;color:#0f172a;">Hello, <span style="color:#15803d;">${studentName || 'Student'}</span></p>
      <p style="margin:0 0 20px;font-size:14px;color:#475569;line-height:1.7;">
        Good news! Your requested school document(s) have been prepared and are ready for pickup at the <strong>Talisay Integrated School Registrar's Office</strong>.
      </p>

      <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:20px 24px;margin-bottom:24px;">
        <p style="margin:0 0 10px;font-size:12px;font-weight:700;color:#166534;text-transform:uppercase;letter-spacing:0.5px;">Ready for Pickup</p>
        <div style="font-size:18px;font-weight:800;color:#14532d;margin-bottom:12px;">&#128197; ${formattedDate}</div>
        <p style="margin:0 0 8px;font-size:13px;font-weight:600;color:#15803d;">Documents:</p>
        <ul style="margin:0;padding-left:20px;font-size:13px;">
          ${docItems}
        </ul>
      </div>

      ${customMsgBlock}

      <div style="margin:24px 0 16px;padding:14px;background:#fffbeb;border:1px solid #fde68a;border-radius:8px;font-size:12px;color:#92400e;line-height:1.6;">
        &#9888; <strong>Reminder:</strong> Please bring a valid Student ID or government-issued ID upon claiming your documents. If an authorized representative is claiming on your behalf, an authorization letter and representative ID are required.
      </div>

      <p style="margin:20px 0 0;font-size:12px;color:#64748b;line-height:1.6;">
        Office Hours: Monday to Friday, 8:00 AM – 5:00 PM.<br>
        Thank you!
      </p>
    `;

    const htmlContent = emailShell(body);

    const mailOptions = {
        from: fromAddress,
        to,
        subject: `[TIS RMS] Documents Ready for Pickup - ${studentName || 'Student'}`,
        html: htmlContent,
        text: `Hello ${studentName || 'Student'},\n\nYour requested document(s) are ready for pickup on ${formattedDate}.\n\nDocuments:\n${docList.map(d => `- ${d}`).join('\n')}\n\nLocation: Talisay Integrated School Registrar's Office.\nPlease bring a valid ID.\n\nThank you!`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = [{
            filename: 'logo.png',
            path: LOGO_PATH,
            cid: 'school-logo'
        }];
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send pickup email to ${to}:`, err.message);
        throw new Error(`Failed to send pickup email: ${err.message}`);
    }
};

module.exports = {
    sendPasswordResetOtp,
    sendPasswordResetLink,
    sendTeacherAttentionReminder,
    sendAccountCreatedEmail,
    sendAccountStatusEmail,
    sendAccountDeletionEmail,
    sendDocumentPickupEmail,
};


