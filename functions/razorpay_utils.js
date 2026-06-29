"use strict";

const crypto = require("node:crypto");

function verifyRazorpaySignature({
  razorpayOrderId,
  razorpayPaymentId,
  razorpaySignature,
  secret,
}) {
  const generated = crypto
    .createHmac("sha256", secret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");

  const generatedBuffer = Buffer.from(generated, "utf8");
  const suppliedBuffer = Buffer.from(razorpaySignature, "utf8");
  return (
    generatedBuffer.length === suppliedBuffer.length &&
    crypto.timingSafeEqual(generatedBuffer, suppliedBuffer)
  );
}

module.exports = {verifyRazorpaySignature};
