'use strict';
const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();
const { validateEmailMEV, validateEmailQEV, extractEmail, parseRecipientEmails } = require('./emailVerifier');

// ── Embedded images ────────────────────────────────────────────────────────────
// Find the absolute path to the school logo (WebP preferred for smaller email payload)
function getLogoPath() {
    const candidates = [
        // WebP optimized copy inside backend (primary — works standalone/deployed)
        path.join(__dirname, '..', '..', 'assets', 'logo.webp'),
        // Local PNG copy inside backend (fallback)
        path.join(__dirname, '..', '..', 'assets', 'logo.png'),
        // Frontend WebP assets folder (fallback — dev environment)
        path.join(__dirname, '..', '..', '..', 'frontend', 'assets', 'images', 'logo.webp'),
        // Frontend PNG assets folder (fallback — dev environment)
        path.join(__dirname, '..', '..', '..', 'frontend', 'assets', 'images', 'logo.png'),
    ];
    for (const p of candidates) {
        if (fs.existsSync(p)) return p;
    }
    return null;
}

const LOGO_PATH = getLogoPath();
const LOGO_FILENAME = LOGO_PATH ? path.basename(LOGO_PATH) : 'logo.webp';
const LOGO_CONTENT_TYPE = LOGO_PATH && LOGO_PATH.toLowerCase().endsWith('.png') ? 'image/png' : 'image/webp';

function getLogoAttachment() {
    if (!LOGO_PATH) return [];
    return [{
        filename: LOGO_FILENAME,
        path: LOGO_PATH,
        cid: 'school-logo',
        contentType: LOGO_CONTENT_TYPE,
    }];
}

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
        connectionTimeout: 15000,
        greetingTimeout: 15000,
        socketTimeout: 60000,
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
    // ── Email Verification Check (MEV) ────────────────────────────────────────
    if (!mailOptions.skipVerification && mailOptions.to) {
        const recipients = parseRecipientEmails(mailOptions.to);
        for (const recipient of recipients) {
            const check = await validateEmailMEV(recipient);
            if (!check.valid) {
                console.warn(`[EmailService] Outgoing email blocked: recipient "${recipient}" is invalid (${check.reason})`);
                const error = new Error(`Recipient email address "${recipient}" is invalid: ${check.reason}`);
                error.code = 'EMAIL_VERIFICATION_FAILED';
                error.verificationDetails = check;
                throw error;
            }
        }
    }

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
        // Do not retry on fallback if the failure was a socket/data timeout after connecting,
        // as Gmail may have already accepted the message (preventing duplicate emails).
        const isPostConnectTimeout = primaryErr.code === 'ETIMEDOUT' && primaryErr.command === 'DATA';
        if (isPostConnectTimeout) {
            throw primaryErr;
        }
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
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>TIS Record Management System</title>
</head>

<body style="
    margin:0;
    padding:0;
    background-color:#ffffff;
    font-family:Arial,Helvetica,sans-serif;
    color:#1f2937;
">

<!-- PREHEADER -->
<div style="
    display:none;
    max-height:0;
    overflow:hidden;
    opacity:0;
    color:transparent;
    mso-hide:all;
">
    TIS Record Management System notification
</div>

<!-- FULL PAGE -->
<table role="presentation"
       width="100%"
       cellpadding="0"
       cellspacing="0"
       border="0"
       style="width:100%;background-color:#ffffff;">

    <tr>
        <td align="center">

            <!-- MAIN CONTAINER -->
            <table role="presentation"
                   width="100%"
                   cellpadding="0"
                   cellspacing="0"
                   border="0"
                   style="
                       width:100%;
                       max-width:720px;
                       background-color:#ffffff;
                   ">

                <!-- HEADER -->
                <tr>
                    <td style="
                        padding:28px 32px 24px;
                        border-bottom:1px solid #e5e7eb;
                    ">

                        <table role="presentation"
                               width="100%"
                               cellpadding="0"
                               cellspacing="0"
                               border="0">

                            <tr>

                                <!-- LOGO -->
                                <td width="56"
                                    valign="middle"
                                    style="
                                        width:56px;
                                        padding-right:16px;
                                    ">
                                    ${headerLogo}
                                </td>

                                <!-- BRAND -->
                                <td valign="middle">

                                    <div style="
                                        font-size:17px;
                                        line-height:23px;
                                        font-weight:bold;
                                        color:#14532d;
                                    ">
                                        Talisay Integrated School
                                    </div>

                                    <div style="
                                        padding-top:2px;
                                        font-size:10px;
                                        line-height:15px;
                                        letter-spacing:.8px;
                                        text-transform:uppercase;
                                        color:#64748b;
                                    ">
                                        Record Management System
                                    </div>

                                </td>

                            </tr>

                        </table>

                    </td>
                </tr>

                <!-- CONTENT -->
                <tr>
                    <td style="
                        padding:42px 32px 48px;
                    ">

                        ${bodyContent}

                    </td>
                </tr>

                <!-- FOOTER -->
                <tr>
                    <td style="
                        padding:20px 32px 24px;
                        border-top:1px solid #e5e7eb;
                        background-color:#fafafa;
                    ">

                        <table role="presentation"
                               width="100%"
                               cellpadding="0"
                               cellspacing="0"
                               border="0">

                            <tr>

                                <td align="left"
                                    valign="middle"
                                    style="
                                        font-size:10px;
                                        line-height:16px;
                                        color:#64748b;
                                    ">

                                    <strong style="color:#475569;">
                                        Talisay Integrated School
                                    </strong><br>

                                    Tiaong, Quezon

                                </td>

                                <td align="right"
                                    valign="middle"
                                    style="
                                        font-size:10px;
                                        line-height:16px;
                                        color:#94a3b8;
                                    ">

                                    &copy; ${YEAR}<br>
                                    Automated message

                                </td>

                            </tr>

                        </table>

                    </td>
                </tr>

            </table>

        </td>
    </tr>

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
    `<td align="center" valign="middle"
        style="
            width:48px;
            height:58px;
            padding:0;
            background-color:#f0fdf4;
            border:1px solid #86efac;
            color:#14532d;
            font-family:'Courier New',Courier,monospace;
            font-size:28px;
            line-height:58px;
            font-weight:bold;
        ">
        ${d}
    </td>`
).join('');

const body = `
    <!-- GREETING -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:bold;
        color:#0f172a;
    ">
        Hello, <span style="color:#15803d;">@${username}</span>
    </p>

    <p style="
        margin:0 0 30px;
        font-size:14px;
        line-height:22px;
        color:#475569;
    ">
        We received a request to reset the password for your
        TIS RMS account. Use the verification code below to
        continue.
    </p>

    <!-- VERIFICATION CODE LABEL -->
    <p style="
        margin:0 0 12px;
        font-size:11px;
        line-height:16px;
        font-weight:bold;
        letter-spacing:1px;
        text-transform:uppercase;
        color:#64748b;
        text-align:center;
    ">
        Verification Code
    </p>

    <!-- OTP -->
    <table role="presentation"
           align="center"
           cellpadding="0"
           cellspacing="5"
           border="0"
           style="margin:0 auto 18px;">
        <tr>
            ${digitBoxes}
        </tr>
    </table>

    <!-- EXPIRATION -->
    <p style="
        margin:0 0 30px;
        text-align:center;
        font-size:12px;
        line-height:18px;
        color:#64748b;
    ">
        This code expires in
        <strong style="color:#475569;">10 minutes</strong>.
    </p>

    <!-- DIVIDER -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 24px;">
        <tr>
            <td height="1"
                style="
                    height:1px;
                    background-color:#e5e7eb;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>
        </tr>
    </table>

    <!-- SECURITY NOTICE -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0;">
        <tr>

            <td width="3"
                style="
                    width:3px;
                    background-color:#f59e0b;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>

            <td style="
                padding:2px 0 2px 14px;
                font-size:12px;
                line-height:19px;
                color:#64748b;
            ">
                <strong style="color:#475569;">
                    Security notice:
                </strong>
                If you did not request a password reset, you can
                safely ignore this email. Your password will remain
                unchanged. If necessary, contact your system
                administrator.
            </td>

        </tr>
    </table>

    <!-- DO NOT SHARE -->
    <p style="
        margin:22px 0 0;
        font-size:11px;
        line-height:17px;
        color:#94a3b8;
        text-align:center;
    ">
        Never share your verification code with anyone.
    </p>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-OTP] Password reset code: ${otp}`,
    html: htmlContent,
    text: `Hello @${username},

We received a request to reset the password for your TIS RMS account.

Your verification code is: ${otp}

This code expires in 10 minutes.

Never share your verification code with anyone.

If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged. If necessary, contact your system administrator.`,
};


    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
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
    <!-- GREETING -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:bold;
        color:#0f172a;
    ">
        Hello, <span style="color:#15803d;">@${username}</span>
    </p>

    <p style="
        margin:0 0 30px;
        font-size:14px;
        line-height:22px;
        color:#475569;
    ">
        An administrator has initiated a password reset for your
        TIS RMS account. Use the button below to create a new
        password.
    </p>

    <!-- RESET PASSWORD LABEL -->
    <p style="
        margin:0 0 12px;
        font-size:11px;
        line-height:16px;
        font-weight:bold;
        letter-spacing:1px;
        text-transform:uppercase;
        color:#64748b;
        text-align:center;
    ">
        Password Reset
    </p>

    <!-- CTA -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 18px;">

        <tr>
            <td align="center">

                <!--[if mso]>
                <v:roundrect
                    xmlns:v="urn:schemas-microsoft-com:vml"
                    href="${resetLink}"
                    style="height:48px;v-text-anchor:middle;width:220px;"
                    arcsize="8%"
                    strokecolor="#15803d"
                    fillcolor="#15803d">

                    <w:anchorlock/>

                    <center style="
                        color:#ffffff;
                        font-family:Arial,Helvetica,sans-serif;
                        font-size:14px;
                        font-weight:bold;
                    ">
                        Reset My Password
                    </center>
                </v:roundrect>
                <![endif]-->

                <!--[if !mso]><!-- -->
                <a href="${resetLink}"
                   target="_blank"
                   style="
                       display:inline-block;
                       min-width:180px;
                       padding:14px 24px;
                       background-color:#15803d;
                       border:1px solid #15803d;
                       color:#ffffff;
                       font-family:Arial,Helvetica,sans-serif;
                       font-size:14px;
                       line-height:20px;
                       font-weight:bold;
                       text-align:center;
                       text-decoration:none;
                   ">
                    Reset My Password
                </a>
                <!--<![endif]-->

            </td>
        </tr>

    </table>

    <!-- EXPIRATION -->
    <p style="
        margin:0 0 30px;
        text-align:center;
        font-size:12px;
        line-height:18px;
        color:#64748b;
    ">
        This password reset link expires in
        <strong style="color:#475569;">
            ${expiresMinutes} minutes
        </strong>
        and can only be used once.
    </p>

    <!-- DIVIDER -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 24px;">

        <tr>
            <td height="1"
                style="
                    height:1px;
                    background-color:#e5e7eb;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>
        </tr>

    </table>

    <!-- FALLBACK LINK -->
    <p style="
        margin:0 0 7px;
        font-size:11px;
        line-height:17px;
        font-weight:bold;
        color:#64748b;
    ">
        Button not working?
    </p>

    <p style="
        margin:0 0 26px;
        font-size:11px;
        line-height:18px;
        word-break:break-all;
        overflow-wrap:anywhere;
    ">
        <a href="${resetLink}"
           target="_blank"
           style="
               color:#15803d;
               text-decoration:underline;
           ">
            ${resetLink}
        </a>
    </p>

    <!-- SECURITY NOTICE -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0;">

        <tr>

            <td width="3"
                style="
                    width:3px;
                    background-color:#94a3b8;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>

            <td style="
                padding:2px 0 2px 14px;
                font-size:12px;
                line-height:19px;
                color:#64748b;
            ">
                <strong style="color:#475569;">
                    Security notice:
                </strong>
                If you did not expect this email, you can safely
                disregard it or contact your system administrator.
                Your password will remain unchanged unless the
                reset link is used.
            </td>

        </tr>

    </table>

    <!-- FINAL SECURITY LINE -->
    <p style="
        margin:22px 0 0;
        font-size:11px;
        line-height:17px;
        color:#94a3b8;
        text-align:center;
    ">
        Never share your password reset link with anyone.
    </p>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-RESET] Password reset link for @${username}`,
    html: htmlContent,
    text: `Hello @${username},

An administrator has initiated a password reset for your TIS RMS account.

Reset your password:
${resetLink}

This password reset link expires in ${expiresMinutes} minutes and can only be used once.

If you did not expect this email, you can safely disregard it or contact your system administrator. Your password will remain unchanged unless the reset link is used.

Never share your password reset link with anyone.`,
};



    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
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
        <tr>
            <td style="
                padding:11px 10px 11px 0;
                border-bottom:1px solid #e5e7eb;
                font-size:13px;
                line-height:19px;
                font-weight:600;
                color:#1e293b;
            ">
                ${s.name}
            </td>

            <td style="
                padding:11px 10px;
                border-bottom:1px solid #e5e7eb;
                font-size:12px;
                line-height:19px;
                color:#475569;
                font-family:'Courier New',Courier,monospace;
                white-space:nowrap;
            ">
                ${s.lrn || 'N/A'}
            </td>

            <td style="
                padding:11px 0 11px 10px;
                border-bottom:1px solid #e5e7eb;
                font-size:12px;
                line-height:19px;
                color:#b91c1c;
                font-weight:500;
            ">
                ${s.missingDocs.join(', ')}
            </td>
        </tr>
    `).join('');

    sectionsHtml += `
        <!-- SECTION -->
        <table role="presentation"
               width="100%"
               cellpadding="0"
               cellspacing="0"
               border="0"
               style="margin:0 0 30px;">

            <!-- SECTION HEADER -->
            <tr>
                <td style="
                    padding:0 0 10px;
                    border-bottom:1px solid #e5e7eb;
                ">

                    <p style="
                        margin:0;
                        font-size:13px;
                        line-height:19px;
                        font-weight:700;
                        color:#0f172a;
                    ">
                        Grade ${sec.gradeLevel} - ${sec.sectionName}
                    </p>

                    <p style="
                        margin:2px 0 0;
                        font-size:11px;
                        line-height:17px;
                        color:#64748b;
                    ">
                        ${sec.students.length}
                        student${sec.students.length > 1 ? 's' : ''}
                        requiring attention
                    </p>

                </td>
            </tr>

            <!-- TABLE -->
            <tr>
                <td style="padding-top:10px;">

                    <table role="presentation"
                           width="100%"
                           cellpadding="0"
                           cellspacing="0"
                           border="0"
                           style="
                               width:100%;
                               border-collapse:collapse;
                           ">

                        <thead>
                            <tr>
                                <th align="left" style="
                                    padding:0 10px 8px 0;
                                    font-size:10px;
                                    line-height:15px;
                                    font-weight:700;
                                    letter-spacing:.6px;
                                    text-transform:uppercase;
                                    color:#64748b;
                                ">
                                    Student
                                </th>

                                <th align="left" style="
                                    padding:0 10px 8px;
                                    font-size:10px;
                                    line-height:15px;
                                    font-weight:700;
                                    letter-spacing:.6px;
                                    text-transform:uppercase;
                                    color:#64748b;
                                ">
                                    LRN
                                </th>

                                <th align="left" style="
                                    padding:0 0 8px 10px;
                                    font-size:10px;
                                    line-height:15px;
                                    font-weight:700;
                                    letter-spacing:.6px;
                                    text-transform:uppercase;
                                    color:#64748b;
                                ">
                                    Missing Requirement(s)
                                </th>
                            </tr>
                        </thead>

                        <tbody>
                            ${rows}
                        </tbody>

                    </table>

                </td>
            </tr>

        </table>
    `;
}

const body = `
    <!-- GREETING -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:700;
        color:#0f172a;
    ">
        Hello, <span style="color:#15803d;">${teacherName}</span>
    </p>

    <!-- INTRODUCTION -->
    <p style="
        margin:0 0 30px;
        font-size:14px;
        line-height:24px;
        color:#475569;
    ">
        This is an automated advisory reminder from the
        <strong style="color:#334155;">
            TIS Record Management System
        </strong>.
        The following
        <strong style="color:#0f172a;">
            ${totalStudents} student${totalStudents > 1 ? 's' : ''}
        </strong>
        in your advised section${sectionsWithStudents.length > 1 ? 's' : ''}
        currently have missing mandatory document requirements.
    </p>

    <!-- SUMMARY -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 30px;">

        <tr>
            <td style="
                padding:14px 16px;
                border-left:4px solid #d97706;
                background-color:#fffbeb;
            ">

                <p style="
                    margin:0 0 4px;
                    font-size:11px;
                    line-height:16px;
                    font-weight:700;
                    letter-spacing:.7px;
                    text-transform:uppercase;
                    color:#92400e;
                ">
                    Needs Attention
                </p>

                <p style="
                    margin:0;
                    font-size:15px;
                    line-height:22px;
                    font-weight:700;
                    color:#78350f;
                ">
                    ${totalStudents}
                    student${totalStudents > 1 ? 's' : ''}
                    with missing mandatory requirements
                </p>

            </td>
        </tr>

    </table>

    <!-- SECTION LIST -->
    ${sectionsHtml}

    <!-- ACTION REQUIRED -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0;">

        <tr>
            <td style="
                padding:15px 16px;
                border-left:3px solid #15803d;
                background-color:#f0fdf4;
            ">

                <p style="
                    margin:0 0 5px;
                    font-size:12px;
                    line-height:18px;
                    font-weight:700;
                    color:#166534;
                ">
                    Action Required
                </p>

                <p style="
                    margin:0;
                    font-size:12px;
                    line-height:19px;
                    color:#166534;
                ">
                    Please coordinate with the concerned students or parents
                    to submit their required documents. You may view and track
                    their document status directly in the TIS RMS advisory portal.
                </p>

            </td>
        </tr>

    </table>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-TEACHER] Advisory reminder: ${totalStudents} Student${totalStudents > 1 ? 's' : ''} Need Document Attention`,
    html: htmlContent,
    text: `Hello ${teacherName},

This is an automated advisory reminder from the TIS Record Management System.

${totalStudents} student${totalStudents > 1 ? 's' : ''} in your advised section${sectionsWithStudents.length > 1 ? 's' : ''} currently have missing mandatory document requirements.

${sectionsWithStudents.map(sec => `
Grade ${sec.gradeLevel} - ${sec.sectionName}
${sec.students.map(s => `- ${s.name} | LRN: ${s.lrn || 'N/A'} | Missing: ${s.missingDocs.join(', ')}`).join('\n')}
`).join('\n')}

Action Required:
Please coordinate with the concerned students or parents to submit their required documents. You may view and track their document status directly in the TIS RMS advisory portal.

Thank you.`,
};

    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
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
    <!-- GREETING -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:bold;
        color:#0f172a;
    ">
        Welcome, <span style="color:#15803d;">${displayName}</span>!
    </p>

    <p style="
        margin:0 0 30px;
        font-size:14px;
        line-height:22px;
        color:#475569;
    ">
        An account has been created for you on the
        <strong style="color:#334155;">
            Talisay Integrated School Record Management System
        </strong>.
        You can now sign in using the credentials below.
    </p>

    <!-- CREDENTIALS LABEL -->
    <p style="
        margin:0 0 12px;
        font-size:11px;
        line-height:16px;
        font-weight:bold;
        letter-spacing:1px;
        text-transform:uppercase;
        color:#64748b;
    ">
        Account Credentials
    </p>

    <!-- CREDENTIALS -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="
               width:100%;
               border-top:1px solid #e5e7eb;
               border-bottom:1px solid #e5e7eb;
               margin:0 0 28px;
           ">

        <!-- USERNAME -->
        <tr>
            <td width="42%"
                style="
                    padding:15px 12px 15px 0;
                    font-size:13px;
                    line-height:20px;
                    font-weight:bold;
                    color:#64748b;
                    border-bottom:1px solid #f1f5f9;
                ">
                Username
            </td>

            <td style="
                padding:15px 0;
                font-size:13px;
                line-height:20px;
                font-weight:bold;
                color:#0f172a;
                font-family:'Courier New',Courier,monospace;
                border-bottom:1px solid #f1f5f9;
            ">
                ${username}
            </td>
        </tr>

        <!-- ROLE -->
        <tr>
            <td width="42%"
                style="
                    padding:15px 12px 15px 0;
                    font-size:13px;
                    line-height:20px;
                    font-weight:bold;
                    color:#64748b;
                    border-bottom:1px solid #f1f5f9;
                ">
                Assigned Role
            </td>

            <td style="
                padding:15px 0;
                font-size:13px;
                line-height:20px;
                font-weight:bold;
                color:#15803d;
                border-bottom:1px solid #f1f5f9;
            ">
                ${roleUpper}
            </td>
        </tr>

        <!-- TEMPORARY PASSWORD -->
        <tr>
            <td width="42%"
                style="
                    padding:15px 12px 15px 0;
                    font-size:13px;
                    line-height:20px;
                    font-weight:bold;
                    color:#64748b;
                ">
                Temporary Password
            </td>

            <td style="
                padding:15px 0;
                font-size:13px;
                line-height:20px;
                font-weight:bold;
                color:#0f172a;
                font-family:'Courier New',Courier,monospace;
                word-break:break-all;
            ">
                ${temporaryPassword}
            </td>
        </tr>

    </table>

    <!-- SECURITY MESSAGE -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 28px;">

        <tr>

            <td width="3"
                style="
                    width:3px;
                    background-color:#1c8248;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>

            <td style="
                padding:2px 0 2px 14px;
                font-size:12px;
                line-height:19px;
                color:#64748b;
            ">
                <strong style="color:#475569;">
                    First sign-in:
                </strong>
                Please change your temporary password immediately
                after signing in. Do not share your credentials with
                anyone.
            </td>

        </tr>

    </table>

    <!-- DIVIDER -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 18px;">

        <tr>
            <td height="1"
                style="
                    height:1px;
                    background-color:#e5e7eb;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>
        </tr>

    </table>

    <!-- UNEXPECTED ACCOUNT -->
    <p style="
        margin:0;
        font-size:11px;
        line-height:18px;
        color:#94a3b8;
    ">
        If you did not expect this account, please contact the
        school administration immediately.
    </p>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-ACCOUNT] Account created for @${username}`,
    html: htmlContent,
    text: `Welcome to TIS Record Management System, ${displayName}!

An account has been created for you.

Username: ${username}
Role: ${roleUpper}
Temporary Password: ${temporaryPassword}

Please sign in and change your temporary password immediately after your first login.

Do not share your credentials with anyone.

If you did not expect this account, please contact the school administration immediately.`,
};

    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
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
    <!-- GREETING -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:bold;
        color:#0f172a;
    ">
        Hello, <span style="color:#15803d;">${displayName}</span>
    </p>

    <p style="
        margin:0 0 30px;
        font-size:14px;
        line-height:22px;
        color:#475569;
    ">
        An administrator has updated the status of your
        TIS Record Management System account.
    </p>

    <!-- STATUS LABEL -->
    <p style="
        margin:0 0 12px;
        font-size:11px;
        line-height:16px;
        font-weight:bold;
        letter-spacing:1px;
        text-transform:uppercase;
        color:#64748b;
    ">
        Account Status
    </p>

    <!-- STATUS -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="
               margin:0 0 28px;
               background-color:${statusBg};
               border:1px solid ${statusBorder};
           ">

        <tr>
            <td width="5"
                style="
                    width:5px;
                    background-color:${statusColor};
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>

            <td style="
                padding:16px 18px;
            ">

                <div style="
                    margin:0 0 4px;
                    font-size:16px;
                    line-height:22px;
                    font-weight:bold;
                    color:${statusColor};
                ">
                    ${statusLabel}
                </div>

                <div style="
                    font-size:13px;
                    line-height:20px;
                    color:#475569;
                ">
                    ${
                        isActive
                            ? 'Your account has been activated by an administrator. You can now sign in to the TIS Record Management System and access school records according to your assigned role.'
                            : 'Your account has been deactivated by an administrator. Your active sessions have been revoked and access to the system has been suspended.'
                    }
                </div>

            </td>
        </tr>

    </table>

    <!-- ADDITIONAL INFORMATION -->
    <p style="
        margin:0 0 28px;
        font-size:13px;
        line-height:20px;
        color:#64748b;
    ">
        ${
            isActive
                ? 'If you have forgotten your password, use the "Forgot Password" option on the sign-in screen.'
                : 'If you believe this status change was made in error, please contact your school administrator or ICT coordinator.'
        }
    </p>

    <!-- DIVIDER -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 18px;">

        <tr>
            <td height="1"
                style="
                    height:1px;
                    background-color:#e5e7eb;
                    font-size:0;
                    line-height:0;
                ">
                &nbsp;
            </td>
        </tr>

    </table>

    <!-- ACCOUNT DETAILS -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0">

        <tr>
            <td style="
                width:50%;
                padding-right:12px;
                font-size:11px;
                line-height:18px;
                color:#94a3b8;
            ">
                Username
            </td>

            <td style="
                width:50%;
                padding-left:12px;
                font-size:11px;
                line-height:18px;
                color:#475569;
                font-weight:bold;
            ">
                ${username}
            </td>
        </tr>

        <tr>
            <td style="
                padding-top:5px;
                padding-right:12px;
                font-size:11px;
                line-height:18px;
                color:#94a3b8;
            ">
                Assigned Role
            </td>

            <td style="
                padding-top:5px;
                padding-left:12px;
                font-size:11px;
                line-height:18px;
                color:#475569;
                font-weight:bold;
            ">
                ${(role || 'user').toUpperCase()}
            </td>
        </tr>

    </table>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-STATUS] Account ${statusLabel}: @${username}`,
    html: htmlContent,
    text: `Hello ${displayName},

Your TIS Record Management System account has been ${statusLabel.toLowerCase()} by an administrator.

${
    isActive
        ? 'You may now log in to the system.'
        : 'Your access has been suspended. Please contact the administrator if this was in error.'
}

Username: ${username}
Role: ${(role || 'user').toUpperCase()}`,
};


    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
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
    <!-- TITLE -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:700;
        color:#0f172a;
    ">
        Account Deletion Request
    </p>

    <!-- INTRODUCTION -->
    <p style="
        margin:0 0 28px;
        font-size:14px;
        line-height:24px;
        color:#475569;
    ">
        Hello, <strong style="color:#0f172a;">@${username}</strong>.
        We received a request to permanently delete your account from the
        <strong style="color:#334155;">
            Talisay Integrated School Record Management System
        </strong>.
    </p>

    <!-- WARNING -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 28px;">

        <tr>
            <td style="
                padding:16px 18px;
                border-left:4px solid #dc2626;
                background-color:#fef2f2;
            ">

                <p style="
                    margin:0 0 5px;
                    font-size:13px;
                    line-height:19px;
                    font-weight:700;
                    color:#991b1b;
                ">
                    Warning: This action is permanent
                </p>

                <p style="
                    margin:0;
                    font-size:12px;
                    line-height:19px;
                    color:#7f1d1d;
                ">
                    Once confirmed, your account credentials will be permanently
                    removed and you will immediately lose access to the system.
                </p>

            </td>
        </tr>

    </table>

    <!-- ACTION LABEL -->
    <p style="
        margin:0 0 12px;
        font-size:11px;
        line-height:16px;
        font-weight:700;
        letter-spacing:.8px;
        text-transform:uppercase;
        color:#64748b;
    ">
        Confirm Account Deletion
    </p>

    <!-- CTA -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 20px;">

        <tr>
            <td align="left">

                <!--[if mso]>
                <v:roundrect
                    xmlns:v="urn:schemas-microsoft-com:vml"
                    href="${deleteLink}"
                    style="height:46px;v-text-anchor:middle;width:220px;"
                    arcsize="0%"
                    fillcolor="#dc2626"
                    strokecolor="#dc2626">

                    <w:anchorlock/>

                    <center style="
                        color:#ffffff;
                        font-family:Arial,Helvetica,sans-serif;
                        font-size:14px;
                        font-weight:bold;
                    ">
                        Confirm &amp; Delete My Account
                    </center>

                </v:roundrect>
                <![endif]-->

                <!--[if !mso]><!-- -->
                <a href="${deleteLink}"
                   target="_blank"
                   style="
                       display:inline-block;
                       background-color:#dc2626;
                       color:#ffffff;
                       font-family:Arial,Helvetica,sans-serif;
                       font-size:14px;
                       line-height:20px;
                       font-weight:700;
                       text-decoration:none;
                       padding:13px 24px;
                   ">
                    Confirm &amp; Delete My Account
                </a>
                <!--<![endif]-->

            </td>
        </tr>

    </table>

    <!-- EXPIRATION -->
    <p style="
        margin:0 0 28px;
        font-size:12px;
        line-height:19px;
        color:#64748b;
    ">
        This confirmation link expires in
        <strong style="color:#334155;">
            ${expiresMinutes} minutes
        </strong>.
    </p>

    <!-- DIVIDER -->
    <div style="
        height:1px;
        background-color:#e5e7eb;
        margin:0 0 20px;
        font-size:0;
        line-height:0;
    ">
        &nbsp;
    </div>

    <!-- SECURITY NOTICE -->
    <p style="
        margin:0 0 10px;
        padding-left:12px;
        border-left:3px solid #94a3b8;
        font-size:12px;
        line-height:19px;
        color:#64748b;
    ">
        If you did not request to delete your account, ignore this email.
        For additional security, consider changing your password immediately.
    </p>

    <!-- FALLBACK LINK -->
    <p style="
        margin:20px 0 0;
        font-size:11px;
        line-height:18px;
        color:#94a3b8;
        word-break:break-all;
    ">
        If the button does not work, copy and paste this link into your browser:<br>
        <a href="${deleteLink}"
           target="_blank"
           style="
               color:#b91c1c;
               text-decoration:underline;
           ">
            ${deleteLink}
        </a>
    </p>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-SECURITY] Confirm account deletion - Action required`,
    html: htmlContent,
    text: `Hello @${username},

We received a request to permanently delete your TIS RMS account.

Warning: This action is permanent and irreversible. Once confirmed, your account credentials will be permanently removed and you will lose access to the system.

To confirm the deletion, click the link below within ${expiresMinutes} minutes:
${deleteLink}

If you did not request this account deletion, please ignore this email. For additional security, consider changing your password immediately.`,
};

    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
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
    .map(d => `
        <tr>
            <td valign="top" style="
                padding:0 0 8px 0;
                font-size:13px;
                line-height:20px;
                color:#1e293b;
                font-weight:600;
            ">
                <span style="color:#15803d;">&#8226;</span>
                &nbsp;${d}
            </td>
        </tr>
    `)
    .join('');

const formattedDate = pickupDate || 'Next School Day';

const customMsgBlock = message && message.trim() ? `
    <!-- OFFICE NOTE -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 28px;">

        <tr>
            <td style="
                padding:15px 16px;
                border-left:3px solid #15803d;
                background-color:#f8fafc;
            ">

                <p style="
                    margin:0 0 5px;
                    font-size:11px;
                    line-height:16px;
                    font-weight:700;
                    letter-spacing:.7px;
                    text-transform:uppercase;
                    color:#64748b;
                ">
                    Note from Office
                </p>

                <p style="
                    margin:0;
                    font-size:13px;
                    line-height:20px;
                    color:#334155;
                ">
                    ${message.trim().replace(/\n/g, '<br>')}
                </p>

            </td>
        </tr>

    </table>
` : '';

const body = `
    <!-- GREETING -->
    <p style="
        margin:0 0 8px;
        font-size:20px;
        line-height:28px;
        font-weight:700;
        color:#0f172a;
    ">
        Hello, <span style="color:#15803d;">${studentName || 'Student'}</span>
    </p>

    <!-- INTRODUCTION -->
    <p style="
        margin:0 0 30px;
        font-size:14px;
        line-height:24px;
        color:#475569;
    ">
        Good news! Your requested school document(s) have been prepared
        and are ready for pickup at the
        <strong style="color:#334155;">
            Talisay Integrated School Registrar's Office
        </strong>.
    </p>

    <!-- PICKUP INFORMATION -->
    <p style="
        margin:0 0 12px;
        font-size:11px;
        line-height:16px;
        font-weight:700;
        letter-spacing:.8px;
        text-transform:uppercase;
        color:#64748b;
    ">
        Ready for Pickup
    </p>

    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 28px;">

        <!-- DATE -->
        <tr>
            <td style="
                padding:14px 0 16px;
                border-left:4px solid #15803d;
                background-color:#f0fdf4;
            ">

                <div style="
                    padding-left:16px;
                    font-size:18px;
                    line-height:25px;
                    font-weight:700;
                    color:#14532d;
                ">
                    ${formattedDate}
                </div>

                <div style="
                    padding:3px 16px 0;
                    font-size:11px;
                    line-height:17px;
                    color:#166534;
                ">
                    Pickup date
                </div>

            </td>
        </tr>

        <!-- DOCUMENTS -->
        <tr>
            <td style="padding-top:18px;">

                <p style="
                    margin:0 0 10px;
                    font-size:11px;
                    line-height:16px;
                    font-weight:700;
                    letter-spacing:.8px;
                    text-transform:uppercase;
                    color:#64748b;
                ">
                    Documents
                </p>

                <table role="presentation"
                       width="100%"
                       cellpadding="0"
                       cellspacing="0"
                       border="0">
                    ${docItems}
                </table>

            </td>
        </tr>

    </table>

    ${customMsgBlock}

    <!-- CLAIMING REMINDER -->
    <table role="presentation"
           width="100%"
           cellpadding="0"
           cellspacing="0"
           border="0"
           style="margin:0 0 28px;">

        <tr>
            <td style="
                padding:15px 16px;
                border-left:3px solid #d97706;
                background-color:#fffbeb;
            ">

                <p style="
                    margin:0 0 5px;
                    font-size:12px;
                    line-height:18px;
                    font-weight:700;
                    color:#92400e;
                ">
                    Reminder
                </p>

                <p style="
                    margin:0;
                    font-size:12px;
                    line-height:19px;
                    color:#92400e;
                ">
                    Please bring a valid Student ID or government-issued ID
                    when claiming your documents. If an authorized
                    representative is claiming on your behalf, an
                    authorization letter and representative ID are required.
                </p>

            </td>
        </tr>

    </table>

    <!-- OFFICE HOURS -->
    <p style="
        margin:0;
        font-size:12px;
        line-height:20px;
        color:#64748b;
    ">
        <strong style="color:#475569;">Office Hours:</strong>
        Monday to Friday, 8:00 AM – 5:00 PM.
    </p>

    <p style="
        margin:8px 0 0;
        font-size:12px;
        line-height:20px;
        color:#64748b;
    ">
        Thank you!
    </p>
`;

const htmlContent = emailShell(body);

const mailOptions = {
    from: fromAddress,
    to,
    subject: `[TIS-PICKUP] Documents ready for pickup - ${studentName || 'Student'}`,
    html: htmlContent,
    text: `Hello ${studentName || 'Student'},

Your requested document(s) are ready for pickup on ${formattedDate}.

Documents:
${docList.map(d => `- ${d}`).join('\n')}

Location: Talisay Integrated School Registrar's Office.

Please bring a valid Student ID or government-issued ID when claiming your documents. If an authorized representative is claiming on your behalf, an authorization letter and representative ID are required.

Office Hours: Monday to Friday, 8:00 AM – 5:00 PM.

Thank you!`,
};

    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send pickup email to ${to}:`, err.message);
        throw new Error(`Failed to send pickup email: ${err.message}`);
    }
};

/**
 * Send user-submitted issue report / feedback directly to the developer via Gmail SMTP
 */
const sendIssueReportEmail = async ({
    category = 'bug',
    urgency = 'medium',
    title,
    description,
    reporter = {},
    systemInfo = {},
    attachments = [],
}) => {
    const smtpUser = (process.env.SMTP_USER || '').trim();
    const developerEmail = (process.env.DEVELOPER_SUPPORT_EMAIL || '').trim();
    const recipientEmail = developerEmail || smtpUser;

    if (!recipientEmail) {
        const msg = 'Issue report email cannot be sent: neither DEVELOPER_SUPPORT_EMAIL nor SMTP_USER is configured.';
        console.warn(`[EmailService] ${msg}`);
        throw new Error(msg);
    }

    const fromAddress = process.env.SMTP_FROM
        || `"TIS RMS Support" <${smtpUser || recipientEmail}>`;

    const categoryLabels = {
        bug: 'Bug Report',
        feature: 'Feature Request',
        question: 'Question / Support',
    };
    const urgencyLabels = {
        high: 'High (Urgent)',
        medium: 'Medium',
        low: 'Low',
    };
    const urgencyColors = {
        high: { bg: '#FEE2E2', text: '#B91C1C', border: '#FCA5A5' },
        medium: { bg: '#FEF3C7', text: '#B45309', border: '#FCD34D' },
        low: { bg: '#CCFBF1', text: '#0F766E', border: '#5EEAD4' },
    };

    const catText = categoryLabels[String(category).toLowerCase()] || String(category).toUpperCase();
    const urgKey = String(urgency).toLowerCase();
    const urgText = urgencyLabels[urgKey] || String(urgency).toUpperCase();
    const urgStyle = urgencyColors[urgKey] || urgencyColors.medium;

    const escapeHtml = (str) => String(str ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');

    const safeTitle = escapeHtml(title);
    const safeDesc = escapeHtml(description).replace(/\n/g, '<br>');
    const reporterName = escapeHtml(reporter.name || 'Unknown User');
    const reporterEmail = escapeHtml(reporter.email || 'N/A');
    const reporterRole = escapeHtml(reporter.role || 'N/A');
    const platform = escapeHtml(systemInfo.platform || 'Unknown');
    const deviceName = escapeHtml(systemInfo.deviceName || 'Unknown');
    const appVersion = escapeHtml(systemInfo.appVersion || 'Unknown');
    const reportedAt = escapeHtml(systemInfo.reportedAt || new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' }));

    const attachmentNamesHtml = attachments.length > 0
        ? `<ul style="margin:6px 0 0;padding-left:18px;color:#374151;font-size:13px;">${attachments
            .map((a) => `<li>${escapeHtml(a.originalname || a.filename)} (${((a.size || 0) / 1024).toFixed(1)} KB)</li>`)
            .join('')}</ul>`
        : '<p style="margin:4px 0 0;color:#6b7280;font-size:13px;">None</p>';

    const htmlContent = emailShell(`
        <h2 style="margin:0 0 8px;color:#111827;font-size:20px;">New Issue Report / Feedback</h2>
        <p style="margin:0 0 18px;color:#6b7280;font-size:13px;">Submitted from TIS RMS Client via in-app support modal</p>

        <div style="margin-bottom:18px;">
            <span style="display:inline-block;padding:4px 10px;border-radius:999px;background:#E5E7EB;color:#1F2937;font-size:12px;font-weight:bold;margin-right:8px;">
                ${escapeHtml(catText)}
            </span>
            <span style="display:inline-block;padding:4px 10px;border-radius:999px;background:${urgStyle.bg};color:${urgStyle.text};border:1px solid ${urgStyle.border};font-size:12px;font-weight:bold;">
                Urgency: ${escapeHtml(urgText)}
            </span>
        </div>

        <div style="background:#F9FAFB;border:1px solid #E5E7EB;border-radius:8px;padding:16px;margin-bottom:18px;">
            <div style="font-size:12px;font-weight:bold;color:#6B7280;text-transform:uppercase;letter-spacing:0.5px;">Subject</div>
            <div style="font-size:16px;font-weight:bold;color:#111827;margin:4px 0 14px;">${safeTitle}</div>
            <div style="font-size:12px;font-weight:bold;color:#6B7280;text-transform:uppercase;letter-spacing:0.5px;">Description</div>
            <div style="font-size:14px;line-height:1.6;color:#1F2937;margin-top:6px;">${safeDesc}</div>
        </div>

        <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;font-size:13px;margin-bottom:16px;">
            <tr>
                <td style="padding:6px 0;color:#6B7280;width:130px;"><strong>Reported By:</strong></td>
                <td style="padding:6px 0;color:#111827;">${reporterName} (${reporterRole}) &lt;${reporterEmail}&gt;</td>
            </tr>
            <tr>
                <td style="padding:6px 0;color:#6B7280;"><strong>Platform:</strong></td>
                <td style="padding:6px 0;color:#111827;">${platform} (${deviceName})</td>
            </tr>
            <tr>
                <td style="padding:6px 0;color:#6B7280;"><strong>App Version:</strong></td>
                <td style="padding:6px 0;color:#111827;">${appVersion}</td>
            </tr>
            <tr>
                <td style="padding:6px 0;color:#6B7280;"><strong>Reported At:</strong></td>
                <td style="padding:6px 0;color:#111827;">${reportedAt}</td>
            </tr>
        </table>

        <div style="border-top:1px solid #E5E7EB;padding-top:12px;">
            <div style="font-size:12px;font-weight:bold;color:#6B7280;text-transform:uppercase;letter-spacing:0.5px;">Attachments (${attachments.length})</div>
            ${attachmentNamesHtml}
        </div>
    `);

    const attachmentListText = attachments.length > 0
        ? attachments.map((a) => `- ${a.originalname || a.filename} (${((a.size || 0) / 1024).toFixed(1)} KB)`).join('\n')
        : 'None';

    const mailOptions = {
        from: fromAddress,
        to: recipientEmail,
        replyTo: reporter.email || undefined,
        subject: `[TIS RMS] [${catText.toUpperCase()}] [${String(urgency).toUpperCase()}] ${title}`,
        html: htmlContent,
        text: `New Issue Report / Feedback

Category: ${catText}
Urgency: ${urgText}
Subject: ${title}

Description:
${description}

Reported By: ${reporter.name || 'Unknown User'} (${reporter.role || 'N/A'}) <${reporter.email || 'N/A'}>
Platform: ${systemInfo.platform || 'Unknown'} (${systemInfo.deviceName || 'Unknown'})
App Version: ${systemInfo.appVersion || 'Unknown'}
Reported At: ${systemInfo.reportedAt || new Date().toISOString()}

Attachments (${attachments.length}):
${attachmentListText}
`,
        skipVerification: true,
        attachments: [
            ...getLogoAttachment(),
            ...attachments.map((file) => ({
                filename: file.originalname || file.filename || 'attachment',
                content: file.buffer,
                contentType: file.mimetype || undefined,
            })),
        ],
    };

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send issue report email:`, err.message);
        throw new Error(`Failed to send issue report email: ${err.message}`);
    }
};

// ── Two-Factor Authentication (2FA) OTP Email ──────────────────────────────────

/**
 * Sends a 6-digit Two-Factor Authentication OTP code to the user's email.
 */
const sendTwoFactorOtp = async ({ to, username, otp, purpose = 'login' }) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const isSetup = purpose === 'setup';
    const introText = isSetup
        ? 'Use the verification code below to enable Email OTP Two-Factor Authentication on your TIS RMS account.'
        : 'A sign-in attempt requires Two-Factor Authentication. Enter the verification code below to finish signing in.';

    const digitBoxes = otp.toString().split('').map(d =>
        `<td align="center" valign="middle"
            style="
                width:48px;
                height:58px;
                padding:0;
                background-color:#f0fdf4;
                border:1px solid #86efac;
                color:#14532d;
                font-family:'Courier New',Courier,monospace;
                font-size:28px;
                line-height:58px;
                font-weight:bold;
            ">
            ${d}
        </td>`
    ).join('');

    const body = `
        <p style="margin:0 0 8px;font-size:20px;line-height:28px;font-weight:bold;color:#0f172a;">
            Hello, <span style="color:#15803d;">@${username}</span>
        </p>
        <p style="margin:0 0 28px;font-size:14px;line-height:22px;color:#475569;">
            ${introText}
        </p>
        <p style="margin:0 0 12px;font-size:11px;line-height:16px;font-weight:bold;letter-spacing:1px;text-transform:uppercase;color:#64748b;text-align:center;">
            Two-Factor Verification Code
        </p>
        <table role="presentation" align="center" cellpadding="0" cellspacing="5" border="0" style="margin:0 auto 18px;">
            <tr>${digitBoxes}</tr>
        </table>
        <p style="margin:0 0 28px;text-align:center;font-size:12px;line-height:18px;color:#64748b;">
            This code expires in <strong style="color:#475569;">10 minutes</strong>.
        </p>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 24px;">
            <tr><td height="1" style="height:1px;background-color:#e5e7eb;font-size:0;line-height:0;">&nbsp;</td></tr>
        </table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0;">
            <tr>
                <td width="3" style="width:3px;background-color:#f59e0b;font-size:0;line-height:0;">&nbsp;</td>
                <td style="padding:2px 0 2px 14px;font-size:12px;line-height:19px;color:#64748b;">
                    <strong style="color:#475569;">Security notice:</strong>
                    If you did not attempt to sign in or configure 2FA, change your password immediately and contact your system administrator.
                </td>
            </tr>
        </table>
        <p style="margin:22px 0 0;font-size:11px;line-height:17px;color:#94a3b8;text-align:center;">
            Never share your verification code with anyone.
        </p>
    `;

    const subject = isSetup
        ? `[TIS-2FA] Verify email for 2FA: ${otp}`
        : `[TIS-2FA] Login verification code: ${otp}`;

    const mailOptions = {
        from: fromAddress,
        to,
        subject,
        html: emailShell(body),
        text: `Hello @${username},\n\n${introText}\n\nYour verification code is: ${otp}\n\nThis code expires in 10 minutes.\n\nNever share your verification code with anyone.`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send 2FA OTP to ${to}:`, err.message);
        throw new Error(`Failed to send email 2FA code: ${err.message}`);
    }
};

/**
 * Security Alert Email sent when a user account is locked out after multiple failed login attempts.
 * Includes a direct 1-click Reset Password link or advises the user to ignore if it was them.
 */
const sendLoginLockoutAlertEmail = async ({
    to,
    username,
    ipAddress = 'Unknown',
    platform = 'Unknown',
    lockoutMinutes = 15,
    resetLink = null,
}) => {
    const fromAddress = process.env.SMTP_FROM
        || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const timestamp = new Date().toLocaleString('en-PH', {
        timeZone: 'Asia/Manila',
        dateStyle: 'medium',
        timeStyle: 'short',
    });

    const resetButtonHtml = resetLink ? `
        <table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="margin:24px auto;">
            <tr>
                <td align="center" bgcolor="#dc2626" style="border-radius:8px;">
                    <a href="${resetLink}" target="_blank" style="display:inline-block;padding:13px 28px;font-size:14px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px;">
                        Reset Password Now
                    </a>
                </td>
            </tr>
        </table>
        <p style="margin:0 0 18px;font-size:11px;line-height:17px;color:#64748b;text-align:center;word-break:break-all;">
            Or copy and open this link (valid for 30 minutes):<br/>
            <a href="${resetLink}" style="color:#15803d;">${resetLink}</a>
        </p>
    ` : '';

    const body = `
        <p style="margin:0 0 8px;font-size:20px;line-height:28px;font-weight:bold;color:#0f172a;">
            Security Alert for <span style="color:#dc2626;">@${username}</span>
        </p>
        <p style="margin:0 0 20px;font-size:14px;line-height:22px;color:#475569;">
            Someone attempted to sign in to your TIS RMS account and entered an incorrect password 5 times.
            To protect your account, sign-in has been temporarily locked for <strong>${lockoutMinutes} minutes</strong>.
        </p>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 20px;background-color:#fef2f2;border:1px solid #fecaca;border-radius:8px;">
            <tr>
                <td style="padding:14px 16px;font-size:13px;line-height:21px;color:#7f1d1d;">
                    <strong>Attempt Details:</strong><br/>
                    &bull; <strong>Time:</strong> ${timestamp}<br/>
                    &bull; <strong>Platform:</strong> ${platform}<br/>
                    &bull; <strong>IP Address:</strong> ${ipAddress}
                </td>
            </tr>
        </table>
        <p style="margin:0 0 8px;font-size:14px;line-height:22px;color:#334155;">
            <strong>Was this not you?</strong><br/>
            If you did not attempt to log in, someone else may be trying to access your account. We strongly recommend resetting your password immediately:
        </p>
        ${resetButtonHtml}
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 16px;">
            <tr><td height="1" style="height:1px;background-color:#e5e7eb;font-size:0;line-height:0;">&nbsp;</td></tr>
        </table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0;">
            <tr>
                <td width="3" style="width:3px;background-color:#15803d;font-size:0;line-height:0;">&nbsp;</td>
                <td style="padding:2px 0 2px 14px;font-size:12px;line-height:19px;color:#64748b;">
                    <strong style="color:#475569;">Was this you?</strong>
                    If you simply mistyped your password, you can safely ignore this email and try again after ${lockoutMinutes} minutes.
                </td>
            </tr>
        </table>
    `;

    const mailOptions = {
        from: fromAddress,
        to,
        subject: `[TIS-Security] Unusual Login Activity — Account Locked (${lockoutMinutes}m)`,
        html: emailShell(body),
        text: `Security Alert for @${username}\n\nSomeone tried to access your TIS RMS account and failed 5 times. Your account has been temporarily locked for ${lockoutMinutes} minutes.\n\nTime: ${timestamp}\nPlatform: ${platform}\nIP Address: ${ipAddress}\n\nIf this was NOT you, reset your password immediately${resetLink ? `: ${resetLink}` : ' using Forgot Password in the app'}.\n\nIf this WAS you, you can safely ignore this email and try again in ${lockoutMinutes} minutes.`,
    };

    if (LOGO_PATH) {
        mailOptions.attachments = getLogoAttachment();
    }

    try {
        return await sendMailWithFallback(mailOptions);
    } catch (err) {
        console.error(`[EmailService] Failed to send lockout alert to ${to}:`, err.message);
        throw err;
    }
};

module.exports = {
    validateEmailMEV,
    validateEmailQEV,
    extractEmail,
    parseRecipientEmails,
    sendPasswordResetOtp,
    sendPasswordResetLink,
    sendTeacherAttentionReminder,
    sendAccountCreatedEmail,
    sendAccountStatusEmail,
    sendAccountDeletionEmail,
    sendDocumentPickupEmail,
    sendIssueReportEmail,
    sendTwoFactorOtp,
    sendLoginLockoutAlertEmail,
};


