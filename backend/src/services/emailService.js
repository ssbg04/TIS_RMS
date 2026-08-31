'use strict';
const nodemailer = require('nodemailer');
require('dotenv').config();

let transporter = null;

const getTransporter = () => {
    const user = process.env.SMTP_USER ? process.env.SMTP_USER.trim() : null;
    const rawPass = process.env.SMTP_PASS ? process.env.SMTP_PASS.trim() : null;
    const pass = rawPass ? rawPass.replace(/\s+/g, '') : null; // Remove any internal spaces from 16-char code

    if (!user || !pass) {
        console.log('[EmailService] SMTP_USER or SMTP_PASS not set. Emails will be logged to console in dev mode.');
        return null;
    }

    // Always create/refresh transporter with sanitized credentials
    transporter = nodemailer.createTransport({
        host: 'smtp.gmail.com',
        port: 465,
        secure: true, // true for port 465, false for other ports
        auth: {
            user: user,
            pass: pass, // 16-character Google App Password (no spaces)
        },
    });

    return transporter;
};

/**
 * Sends a 6-digit password reset OTP to user's email.
 * @param {Object} options
 * @param {string} options.to - Recipient email address
 * @param {string} options.username - Account username
 * @param {string} options.otp - 6-digit OTP string
 */
const sendPasswordResetOtp = async ({ to, username, otp }) => {
    const mailTransporter = getTransporter();
    const fromAddress = process.env.SMTP_FROM || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 20px; }
            .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
            .header { background: linear-gradient(135deg, #15803D 0%, #166534 100%); color: #ffffff; padding: 24px; text-align: center; }
            .header h1 { margin: 0; font-size: 20px; font-weight: 700; letter-spacing: 0.5px; }
            .header p { margin: 4px 0 0 0; font-size: 13px; opacity: 0.9; }
            .content { padding: 32px 24px; text-align: center; }
            .greeting { font-size: 16px; font-weight: 600; color: #0f172a; margin-bottom: 8px; text-align: left; }
            .instructions { font-size: 14px; color: #475569; line-height: 1.6; margin-bottom: 24px; text-align: left; }
            .otp-box { background: #f0fdf4; border: 2px dashed #22c55e; border-radius: 8px; padding: 18px 24px; margin: 20px 0; display: inline-block; }
            .otp-code { font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #15803D; font-family: 'Courier New', Courier, monospace; margin: 0; }
            .expiry-note { font-size: 12px; color: #64748b; margin-top: 12px; }
            .warning { background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px; margin-top: 24px; text-align: left; font-size: 12px; color: #92400e; border-radius: 0 6px 6px 0; }
            .footer { background: #f1f5f9; padding: 16px 24px; text-align: center; font-size: 11px; color: #64748b; border-top: 1px solid #e2e8f0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Talisay Integrated School</h1>
                <p>Record Management System — Password Reset</p>
            </div>
            <div class="content">
                <div class="greeting">Hello @${username},</div>
                <div class="instructions">
                    We received a request to reset the password for your TIS RMS account. Please use the verification code below to complete your password reset:
                </div>
                <div class="otp-box">
                    <div class="otp-code">${otp}</div>
                </div>
                <div class="expiry-note">⏱️ This code will expire in <strong>10 minutes</strong>.</div>
                <div class="warning">
                    <strong>Security Notice:</strong> If you did not request this password reset, please ignore this email or notify your system administrator immediately.
                </div>
            </div>
            <div class="footer">
                &copy; ${new Date().getFullYear()} Talisay Integrated School. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    `;

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
        const info = await mailTransporter.sendMail({
            from: fromAddress,
            to: to,
            subject: `[TIS RMS] Password Reset Code: ${otp}`,
            html: htmlContent,
            text: `Hello @${username},\n\nYour TIS RMS password reset code is: ${otp}\n\nThis code will expire in 10 minutes.\n\nIf you did not request this reset, please contact your administrator.`,
        });

        console.log(`[EmailService] Password reset OTP sent to ${to} (Message ID: ${info.messageId})`);
        return { success: true, messageId: info.messageId };
    } catch (err) {
        console.error(`[EmailService] Failed to send email to ${to}:`, err.message);
        throw new Error(`Failed to send email OTP: ${err.message}`);
    }
};

/**
 * Sends a password reset link with expiration time to user's email.
 * @param {Object} options
 * @param {string} options.to - Recipient email address
 * @param {string} options.username - Account username
 * @param {string} options.resetLink - Full URL for resetting password
 * @param {number} options.expiresMinutes - Expiration duration in minutes
 */
const sendPasswordResetLink = async ({ to, username, resetLink, expiresMinutes = 15 }) => {
    const mailTransporter = getTransporter();
    const fromAddress = process.env.SMTP_FROM || `"TIS Record Management System" <${process.env.SMTP_USER || 'no-reply@talisayis.edu.ph'}>`;

    const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif; background-color: #f1f5f9; color: #1e293b; margin: 0; padding: 24px 12px; }
            .container { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05); }
            .header { background: linear-gradient(135deg, #15803D 0%, #166534 100%); color: #ffffff; padding: 28px 24px; text-align: center; }
            .header h1 { margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px; }
            .header p { margin: 6px 0 0 0; font-size: 13px; opacity: 0.92; }
            .content { padding: 32px 28px; text-align: left; }
            .greeting { font-size: 17px; font-weight: 700; color: #0f172a; margin-bottom: 12px; }
            .instructions { font-size: 14px; color: #475569; line-height: 1.6; margin-bottom: 24px; }
            .btn-container { text-align: center; margin: 28px 0; }
            .reset-btn { display: inline-block; background-color: #15803D; color: #ffffff !important; font-size: 15px; font-weight: 700; text-decoration: none; padding: 14px 32px; border-radius: 10px; box-shadow: 0 4px 12px rgba(21, 128, 61, 0.35); transition: background-color 0.2s ease; letter-spacing: 0.3px; }
            .expiry-badge { background-color: #fef3c7; border: 1px solid #fde68a; border-radius: 8px; padding: 10px 14px; font-size: 13px; color: #92400e; margin: 20px 0; display: flex; align-items: center; }
            .raw-link { font-size: 12px; color: #64748b; margin-top: 24px; line-height: 1.5; word-break: break-all; }
            .raw-link a { color: #15803D; }
            .warning { background: #f8fafc; border-left: 4px solid #94a3b8; padding: 12px 16px; margin-top: 24px; font-size: 12px; color: #64748b; border-radius: 0 8px 8px 0; }
            .footer { background: #f8fafc; padding: 20px 24px; text-align: center; font-size: 11px; color: #64748b; border-top: 1px solid #e2e8f0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Talisay Integrated School</h1>
                <p>Record Management System — Password Reset</p>
            </div>
            <div class="content">
                <div class="greeting">Hello @${username},</div>
                <div class="instructions">
                    An administrator has requested a password reset for your TIS RMS account. Please click the button below to set your new password:
                </div>
                <div class="btn-container">
                    <a href="${resetLink}" target="_blank" class="reset-btn">Reset My Password</a>
                </div>
                <div class="expiry-badge">
                    ⏱️ <strong>Note:</strong> This password reset link will expire in <strong>${expiresMinutes} minutes</strong>.
                </div>
                <div class="raw-link">
                    If the button above does not work, copy and paste this link into your web browser:<br>
                    <a href="${resetLink}">${resetLink}</a>
                </div>
                <div class="warning">
                    <strong>Security Notice:</strong> If you did not expect this password reset or believe this was done in error, please contact your system administrator immediately.
                </div>
            </div>
            <div class="footer">
                &copy; ${new Date().getFullYear()} Talisay Integrated School. All rights reserved.<br>
                This is an automated system notification, please do not reply directly to this email.
            </div>
        </div>
    </body>
    </html>
    `;

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
        const info = await mailTransporter.sendMail({
            from: fromAddress,
            to: to,
            subject: `[TIS RMS] Password Reset Link for @${username}`,
            html: htmlContent,
            text: `Hello @${username},\n\nAn administrator requested a password reset for your TIS RMS account.\n\nPlease use this link to reset your password:\n${resetLink}\n\nThis link will expire in ${expiresMinutes} minutes.\n\nIf you did not request this, please contact your administrator.`,
        });

        console.log(`[EmailService] Password reset link sent to ${to} (Message ID: ${info.messageId})`);
        return { success: true, messageId: info.messageId };
    } catch (err) {
        console.error(`[EmailService] Failed to send email link to ${to}:`, err.message);
        throw new Error(`Failed to send email link: ${err.message}`);
    }
};

module.exports = {
    sendPasswordResetOtp,
    sendPasswordResetLink,
};

