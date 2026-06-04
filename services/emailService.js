const nodemailer = require('nodemailer');

const sendEmail = async ({ to, subject, html }) => {
  try {
    const smtpHost = process.env.SMTP_HOST;
    const smtpPort = process.env.SMTP_PORT || 465;
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;
    const fromEmail = process.env.SMTP_FROM || smtpUser || 'no-reply@retailverse.com';

    // If SMTP is not configured, log and return mock
    if (!smtpHost || !smtpUser || !smtpPass) {
      console.warn("SMTP credentials missing, falling back to basic Nodemailer logging.");
      console.log(`[EMAIL MOCK] To: ${to}, Subject: ${subject}`);
      return { messageId: 'mock-' + Date.now() };
    }

    // Create Nodemailer transporter
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: Number(smtpPort),
      secure: Number(smtpPort) === 465, // true for 465, false for other ports
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });

    // Send mail
    const info = await transporter.sendMail({
      from: `"Retail Verse" <${fromEmail}>`,
      to: to,
      subject: subject,
      html: html,
    });

    console.log('Message sent via Nodemailer:', info.messageId);
    return { messageId: info.messageId };
  } catch (error) {
    console.error('Error sending email:', error);
    throw error;
  }
};

module.exports = {
  sendEmail,
};
