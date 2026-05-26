const nodemailer = require("nodemailer");
const Ticket = require("../models/Ticket");
const Notification = require("../models/Notification");
const { createAndSendNotification } = require("../services/notificationService");

const sendEmailInvoice = async (req, res) => {
  const { to, subject, htmlContent } = req.body;

  if (!to || !subject || !htmlContent) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const subdomain = process.env.ZENDESK_SUBDOMAIN;
    const zendeskEmail = process.env.ZENDESK_EMAIL;
    const apiToken = process.env.ZENDESK_API_TOKEN;

    let zendeskTicketId = null;

    // 1. Create a ticket in Zendesk (this emails the customer)
    if (subdomain && zendeskEmail && apiToken) {
      try {
        const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json`;
        const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

        const ticketData = {
          ticket: {
            subject: subject,
            comment: {
              html_body: htmlContent // Zendesk uses html_body for HTML comments
            },
            requester: {
              name: "Customer",
              email: to
            }
          }
        };

        const response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": authHeader
          },
          body: JSON.stringify(ticketData)
        });

        if (response.ok) {
          const data = await response.json();
          zendeskTicketId = data.ticket?.id;
          console.log(`✅ Invoice sent via Zendesk. Ticket ID: ${zendeskTicketId}`);
        } else {
          console.error("Zendesk invoice sync status not ok:", response.status);
        }
      } catch (zendeskErr) {
        console.error("Zendesk invoice sync failed:", zendeskErr.message);
      }
    } else {
      // Fallback to Nodemailer if Zendesk is not configured
      try {
        const transporter = nodemailer.createTransport({
          service: 'gmail',
          auth: {
            user: process.env.GMAIL_USER,
            pass: process.env.GMAIL_PASS, 
          },
        });
        const mailOptions = {
          from: `"Retail Verse" <${process.env.GMAIL_USER}>`,
          to,
          subject,
          html: htmlContent,
        };
        const info = await transporter.sendMail(mailOptions);
        console.log("Message sent via Nodemailer: %s", info.messageId);
      } catch (err) {
        console.error("Nodemailer fallback failed:", err);
      }
    }

    // 2. Create local Ticket so the 'total tickets' count increases in the support dashboard
    try {
      const ticketId = Math.floor(100000 + Math.random() * 900000);
      const localTicket = new Ticket({
        ticketId,
        subject: subject,
        message: "Invoice sent to customer via email.", // Simple text for local dashboard
        userName: "Customer",
        email: to,
        role: "customer",
        businessName: "Retail Verse",
        storeId: "N/A",
        clientId: req.user?.clientId,
        status: "open",
        priority: "normal"
      });
      await localTicket.save();
    } catch (dbErr) {
      console.error("Error saving local ticket for invoice:", dbErr);
    }

    res.status(200).json({ message: "Email sent and ticket created successfully" });
  } catch (error) {
    console.error("Error sending email:", error);
    res.status(500).json({ message: "Failed to send email", error: error.message });
  }
};

const getNotifications = async (req, res) => {
  try {
    const userId = req.user._id;
    const userRole = req.user.role;
    const clientId = req.user.clientId;

    const query = {
      targetRoles: userRole,
    };

    if (clientId) {
      query.$or = [{ clientId }, { clientId: null }];
    } else {
      query.clientId = null;
    }

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .limit(50);

    const unreadCount = notifications.filter(
      (n) => !n.readBy.includes(userId)
    ).length;

    res.status(200).json({ success: true, notifications, unreadCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const markAsRead = async (req, res) => {
  try {
    const userId = req.user._id;

    // We can mark all as read for this user, or just one
    // For simplicity, mark all matching notifications as read
    const userRole = req.user.role;
    const clientId = req.user.clientId;

    const query = {
      targetRoles: userRole,
      readBy: { $ne: userId }
    };

    if (clientId) {
      query.$or = [{ clientId }, { clientId: null }];
    } else {
      query.clientId = null;
    }

    await Notification.updateMany(query, { $push: { readBy: userId } });

    res.status(200).json({ success: true, message: "Marked as read" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const broadcastNotification = async (req, res) => {
  try {
    const { title, message, targetRoles, type } = req.body;
    
    // Only super_admin should broadcast globally without clientId
    let clientId = req.user.clientId;
    if (req.user.role === "super_admin" && !req.body.clientId) {
      clientId = null; // Global broadcast
    }

    await createAndSendNotification({
      title,
      message,
      type: type || "general",
      targetRoles: targetRoles || ["admin", "client", "customer"],
      clientId,
    });

    res.status(200).json({ success: true, message: "Broadcast sent successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const requestRestock = async (req, res) => {
  try {
    const { productId, note } = req.body;
    const clientId = req.user.clientId;
    
    // In a real scenario, you'd fetch the product name, but we can just use generic if needed.
    // For now, simple text:
    const title = "Restock Requested 🚨";
    const message = `A restock was requested by ${req.user.name || 'Cashier'} ${note ? '- Note: ' + note : ''}`;
    
    await createAndSendNotification({
      title,
      message,
      type: "low_stock",
      targetRoles: ["inventory", "admin"],
      clientId,
      data: { productId }
    });
    
    res.status(200).json({ success: true, message: "Restock request sent" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { sendEmailInvoice, getNotifications, markAsRead, broadcastNotification, requestRestock };
