require 'prawn'

class ReceiptGeneratorService
  def initialize(order)
    @order = order
  end

  # Generates a PDF receipt and updates the order's receipt_url.
  #
  # @return [Boolean] true if receipt was generated and updated, false otherwise.
  def generate_pdf_and_attach
    # Ensure the order is in a paid or cash-on-delivery status before generating a receipt
    unless ['Paystack Paid', 'Mpesa Paid', 'Cash on Delivery'].include?(@order.payment_status)
      Rails.logger.warn "Receipt not generated for order #{@order.id} as payment status is '#{@order.payment_status}'."
      return false
    end

    # Define the path where the PDF will be temporarily saved
    # For production, consider using Active Storage to attach files to your models
    # and store them on cloud storage like AWS S3.
    pdf_filename = "receipt_order_#{@order.id}.pdf"
    pdf_file_path = Rails.root.join('public', 'receipts', pdf_filename) # Store in public/receipts

    # Ensure the directory exists
    FileUtils.mkdir_p(File.dirname(pdf_file_path)) unless File.directory?(File.dirname(pdf_file_path))

    Prawn::Document.generate(pdf_file_path) do |pdf|
      # Header
      pdf.font "Helvetica"
      pdf.text "Liquor Store - Official Receipt", size: 24, style: :bold, align: :center
      pdf.move_down 20

      # Order Details
      pdf.text "Order ##{@order.id}", size: 18, style: :bold
      pdf.text "Date: #{@order.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      pdf.text "Customer: #{@order.user&.first_name} #{@order.user&.last_name} (#{@order.user&.email})" # Access user details
      pdf.text "Delivery Address: #{@order.address&.street_address}, #{@order.address&.location}"
      pdf.move_down 15

      # Order Items Table
      pdf.text "Order Items:", size: 16, style: :bold
      pdf.move_down 5

      items_data = [["Product", "Size", "Quantity", "Price/Unit", "Total"]]
      @order.order_items.each do |item|
        items_data << [
          item.product.name,
          item.size,
          item.quantity,
          "KES #{item.price_per_unit.to_f.round(2)}",
          "KES #{(item.quantity * item.price_per_unit).to_f.round(2)}"
        ]
      end

      pdf.table(items_data, header: true,
                              column_widths: { 0 => 200, 1 => 80, 2 => 70, 3 => 80, 4 => 80 },
                              cell_style: { border_width: 0.5, padding: 5 }) do
        row(0).font_style = :bold
        row(0).background_color = 'DDDDDD'
      end
      pdf.move_down 10

      # Totals
      pdf.text "Subtotal: KES #{@order.order_items.sum { |item| item.quantity * item.price_per_unit }.to_f.round(2)}", align: :right
      pdf.text "Delivery Fee: KES 0.00", align: :right # Assuming delivery fee is part of total_price or added later
      pdf.text "<b>Total Paid: KES #{@order.total_price.to_f.round(2)}</b>", size: 16, style: :bold, align: :right
      pdf.move_down 20

      # Payment Details
      pdf.text "Payment Details:", size: 16, style: :bold
      if @order.payment_status == 'Paystack Paid'
        pdf.text "Method: Paystack"
        pdf.text "Paystack Reference: #{@order.paystack_reference}"
        pdf.text "Transaction ID: #{@order.paystack_transaction_id}"
        pdf.text "Channel: #{@order.paystack_channel}"
        pdf.text "Amount: KES #{@order.paystack_amount.to_f.round(2)}"
      elsif @order.payment_status == 'Mpesa Paid' # If you later integrate Mpesa directly
        pdf.text "Method: M-Pesa"
        pdf.text "M-Pesa Receipt: #{@order.mpesa_receipt_number}"
        pdf.text "M-Pesa Transaction ID: #{@order.mpesa_transaction_id}"
        pdf.text "Amount: KES #{@order.mpesa_amount.to_f.round(2)}"
      elsif @order.payment_status == 'Cash on Delivery'
        pdf.text "Method: Cash on Delivery"
      end
      pdf.move_down 20

      # Footer
      pdf.text "Thank you for your business!", align: :center, size: 14
      pdf.text "For support, contact us at support@liquorstore.com", align: :center, size: 10
    end

    # Update the order with the public URL to the receipt
    # This URL will be accessible from the frontend
    receipt_public_url = "/receipts/#{pdf_filename}"
    @order.update(receipt_url: receipt_public_url)

    Rails.logger.info "Receipt PDF generated for Order #{@order.id} at #{pdf_file_path}"
    true
  rescue => e
    Rails.logger.error "Error generating receipt for Order #{@order.id}: #{e.message}"
    false
  end
end
