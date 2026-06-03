const nodemailer = require('nodemailer');

const sendEmail = async ({ to, subject, html }) => {
  try {
    // If BREVO_API_KEY is set, use the HTTP API (Bypasses Render SMTP block)
    if (process.env.BREVO_API_KEY) {
      const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'accept': 'application/json',
          'api-key': process.env.BREVO_API_KEY,
          'content-type': 'application/json'
        },
        body: JSON.stringify({
          sender: { 
            email: process.env.SMTP_USER || 'info@hexerve.com', 
            name: 'Retail Verse' 
          },
          to: [{ email: to }],
          subject: subject,
          htmlContent: html
        })
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(`Brevo API Error: ${response.status} ${JSON.stringify(errorData)}`);
      }
      
      console.log('Message sent via Brevo HTTP API');
      return { messageId: 'brevo-' + Date.now() };
    }

    // Fallback to Nodemailer (Will fail on Render Free Tier due to port 587 block)
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: process.env.SMTP_PORT || 587,
      secure: false, // true for 465, false for other ports
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    const mailOptions = {
      from: `"Retail Verse" <${process.env.SMTP_USER || 'noreply@retailverse.com'}>`,
      to,
      subject,
      html,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Message sent via Nodemailer: %s', info.messageId);
    return info;
  } catch (error) {
    console.error('Error sending email:', error);
    throw error;
  }
};

module.exports = {
  sendEmail,
};
