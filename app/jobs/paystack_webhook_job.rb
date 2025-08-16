class PaystackWebhookJob < ApplicationJob
  queue_as :default # Or a specific queue for payment processing

  # This method is called when the job is executed.
  # It receives the Paystack webhook payload.
  def perform(payload)
    event_type = payload['event']
    transaction_data = payload['data']
    reference = transaction_data['reference']

    # Find the corresponding order using the Paystack reference
    order = Order.find_by(paystack_reference: reference)

    unless order
      Rails.logger.error "Paystack webhook job: Order not found for reference: #{reference}. Event: #{event_type}"
      return # Exit if order not found
    end

    case event_type
    when 'charge.success'
      # Payment was successful. Update order status and details.
      order.update(
        payment_status: 'Paystack Paid',
        status: 'confirmed', # Order is now confirmed and ready for fulfillment
        paystack_transaction_id: transaction_data['id'],
        paystack_status: transaction_data['status'], # 'success'
        paystack_channel: transaction_data['channel'], # 'mobile_money', 'card', etc.
        paystack_amount: transaction_data['amount'].to_f / 100, # Convert kobo/cents back to KES
        paystack_currency: transaction_data['currency']
      )
      Rails.logger.info "Order #{order.id} successfully paid via Paystack. Status updated to 'confirmed'."

      # --- Automated Actions after successful payment ---
      # 1. Generate Receipt:
      #    Call the receipt generation service.
      ReceiptGeneratorService.new(order).generate_pdf_and_attach
      # 2. Send Confirmation Email/SMS (conceptual):
      #    OrderMailer.confirmation_email(order).deliver_later
      # 3. Notify Admin (conceptual):
      #    AdminNotifier.new_order_notification(order).deliver_later
      # --------------------------------------------------

    when 'charge.failed', 'charge.abandoned'
      # Payment failed or was abandoned by the customer.
      order.update(
        payment_status: 'Paystack Failed',
        status: 'payment_failed', # Mark order as failed payment
        paystack_status: transaction_data['status'], # 'failed', 'abandoned'
        paystack_channel: transaction_data['channel']
      )
      Rails.logger.warn "Paystack payment failed for Order #{order.id}. Status updated to 'payment_failed'."
      # You might want to notify the customer of failure and allow them to retry.

    # Add other relevant Paystack events if needed (e.g., 'transfer.success', 'transfer.failed')
    else
      Rails.logger.info "Unhandled Paystack event type: #{event_type} for order #{order.id}. No status change."
    end
  rescue => e
    Rails.logger.error "Error processing Paystack webhook for reference #{reference}: #{e.message}"
    # Implement robust error logging and alerting for unhandled exceptions in the job
  end
end