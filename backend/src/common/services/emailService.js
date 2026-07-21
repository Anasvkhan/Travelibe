import nodemailer from 'nodemailer';
import { config } from '../../config.js';

export class EmailService {
  static getTransporter() {
    return nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true, // true for 465, false for other ports
      auth: {
        user: config.smtpUser,
        pass: config.smtpPass,
      },
    });
  }

  static async sendOtpEmail(to, otp) {
    const transporter = this.getTransporter();

    const mailOptions = {
      from: `"Travelibe Security" <${config.smtpUser}>`,
      to,
      subject: 'Verify Your Travelibe Email Account',
      html: `
        <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 8px;">
          <h2 style="color: #0d9488; text-align: center;">Travelibe</h2>
          <p>Hello,</p>
          <p>Thank you for choosing Travelibe! Please use the following 6-digit One-Time Password (OTP) to verify your email address. This OTP is valid for 10 minutes.</p>
          <div style="text-align: center; margin: 30px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #f43f5e; background-color: #f1f5f9; padding: 10px 20px; border-radius: 4px; display: inline-block;">
              ${otp}
            </span>
          </div>
          <p style="color: #64748b; font-size: 13px;">If you did not request this verification, please ignore this email.</p>
          <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;" />
          <p style="color: #94a3b8; font-size: 11px; text-align: center;">&copy; 2026 Travelibe Inc. All rights reserved.</p>
        </div>
      `,
    };

    return await transporter.sendMail(mailOptions);
  }

  static async sendBookingConfirmationEmail(to, details) {
    const transporter = this.getTransporter();

    const mailOptions = {
      from: `"Travelibe Bookings" <${config.smtpUser}>`,
      to,
      subject: 'Your Travelibe Booking Confirmation',
      html: `
        <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 8px;">
          <h2 style="color: #0d9488; text-align: center;">Booking Confirmed!</h2>
          <p>Hi,</p>
          <p>Thank you for your booking! Your payment was successful and your reservation is now active.</p>
          <div style="background-color: #f1f5f9; padding: 16px; border-radius: 6px; margin: 20px 0;">
            <p style="margin: 4px 0;"><strong>Stay:</strong> ${details.propertyName}</p>
            <p style="margin: 4px 0;"><strong>Dates:</strong> ${details.checkIn} to ${details.checkOut}</p>
            <p style="margin: 4px 0;"><strong>Total Paid:</strong> $${details.amount}</p>
            <p style="margin: 4px 0;"><strong>Status:</strong> <span style="color: #10b981; font-weight: bold;">PAID</span></p>
          </div>
          <p style="color: #64748b; font-size: 13px;">If you have any questions about your stay, feel free to contact host services or organize details with fellow travelers.</p>
          <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;" />
          <p style="color: #94a3b8; font-size: 11px; text-align: center;">&copy; 2026 Travelibe Inc. All rights reserved.</p>
        </div>
      `,
    };

    return await transporter.sendMail(mailOptions);
  }
}

export default EmailService;
