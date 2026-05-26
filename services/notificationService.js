const Notification = require("../models/Notification");
const User = require("../models/User");
const { sendPushNotificationToTokens } = require("./fcmService");

/**
 * Creates a notification in DB and sends a Push Notification.
 * Also ensures the Admin of the store gets a copy if employees are targeted.
 */
const createAndSendNotification = async ({
  title,
  message,
  type = "general",
  targetRoles = [],
  clientId = null,
  data = {},
}) => {
  try {
    // 1. If targeting employees, always ensure 'admin' is included
    const employeeRoles = ["inventory", "cashier", "seo_manager", "user"];
    const hasEmployee = targetRoles.some((role) => employeeRoles.includes(role));
    
    let finalRoles = [...targetRoles];
    if (hasEmployee && !finalRoles.includes("admin")) {
      finalRoles.push("admin");
    }

    // 2. Save Notification to Database
    const notification = await Notification.create({
      title,
      message,
      type,
      targetRoles: finalRoles,
      clientId,
    });

    // 3. Find Users to send Push Notifications
    const query = {
      role: { $in: finalRoles },
      fcmToken: { $exists: true, $ne: "" },
    };

    if (clientId) {
      query.clientId = clientId;
    }

    const users = await User.find(query);
    const tokens = users.map((u) => u.fcmToken);

    // 4. Send Push Notification
    if (tokens.length > 0) {
      await sendPushNotificationToTokens(tokens, title, message, {
        ...data,
        notificationId: notification._id.toString(),
        type,
      });
    }

    return notification;
  } catch (error) {
    console.error("Error creating and sending notification:", error);
  }
};

module.exports = {
  createAndSendNotification,
};
