require 'prawn'
require 'prawn/table'
require 'stringio'

class ReceiptGeneratorService
  def initialize(order)
    @order = order
  end

  def generate_pdf_and_attach
    Rails.logger.info "=== GENERATING RECEIPT FOR ORDER #{@order.id} ==="
    Rails.logger.info "Payment Status: #{@order.payment_status}"
    
    unless ['Paystack Paid', 'Mpesa Paid', 'Cash on Delivery'].include?(@order.payment_status)
      Rails.logger.warn "Receipt not generated for order #{@order.id} as payment status is '#{@order.payment_status}'."
      return false
    end

    begin
      pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
      generate_professional_receipt(pdf)
      pdf_content = pdf.render

      pdf_filename = "receipt_order_#{@order.id}_#{Time.current.to_i}.pdf"

      @order.receipt.attach(
        io: StringIO.new(pdf_content),
        filename: pdf_filename,
        content_type: 'application/pdf'
      )

      if @order.receipt.attached?
        Rails.logger.info "Receipt attached successfully to S3 for Order #{@order.id}"
        return true
      else
        Rails.logger.error "Failed to attach receipt to S3 for Order #{@order.id}"
        return false
      end
    rescue => e
      Rails.logger.error "Error generating receipt for Order #{@order.id}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      return false
    end
  end

  private

  def generate_professional_receipt(pdf)
    pdf.font "Helvetica"
    
    # Header section with title
    generate_header_section(pdf)
    
    # Company and order info section
    generate_company_info_section(pdf)
    
    # Customer billing section
    generate_customer_section(pdf)
    
    # Order items table
    generate_items_table(pdf)
    
    # Payment information section
    generate_payment_section(pdf)
    
    # Footer
    generate_footer(pdf)
  end

  def generate_header_section(pdf)
    # Official Receipt header
    header_data = [["OFFICIAL RECEIPT"]]
    pdf.table(header_data, 
      width: pdf.bounds.width,
      cell_style: {
        size: 16,
        font_style: :bold,
        align: :center,
        padding: [10, 0],
        borders: [],
        background_color: 'F8F9FA'
      }
    )
    pdf.move_down 20
  end

  def generate_company_info_section(pdf)
    # Company name and invoice details
    company_info_data = [
      ["Liquor Chapchap", "Invoice No. #{@order.id.to_s.rjust(5, '0')}"],
      ["", "#{@order.created_at.strftime('%d %B %Y at %I:%M %p')}"]
    ]
    
    pdf.table(company_info_data,
      width: pdf.bounds.width,
      column_widths: [pdf.bounds.width * 0.6, pdf.bounds.width * 0.4],
      cell_style: {
        borders: [],
        padding: [5, 0]
      }
    ) do |table|
      # Company name styling
      table.row(0).column(0).style(
        size: 28,
        font_style: :bold
      )
      
      # Invoice info styling
      table.row(0).column(1).style(
        size: 12,
        font_style: :bold,
        align: :right
      )
      
      table.row(1).column(1).style(
        size: 10,
        align: :right
      )
    end
    
    pdf.move_down 30
  end

  def generate_customer_section(pdf)
    customer_name = "#{@order.user&.first_name} #{@order.user&.last_name}".strip
    customer_name = "Walk-in Customer" if customer_name.blank?
    
    address_text = @order.shipping_address ? 
      "#{@order.shipping_address.street_address}, #{@order.shipping_address.location}" : 
      "N/A"
    
    # Billed to section
    billing_data = [
      ["Billed to:"],
      [customer_name],
      [@order.user&.email || 'N/A'],
      [address_text]
    ]
    
    pdf.table(billing_data,
      width: pdf.bounds.width * 0.5,
      cell_style: {
        borders: [],
        padding: [2, 0]
      }
    ) do |table|
      table.row(0).style(
        size: 11,
        font_style: :bold
      )
      table.row(1).style(
        size: 12,
        font_style: :bold
      )
      table.rows(2..-1).style(
        size: 10
      )
    end
    
    pdf.move_down 40
  end

  def generate_items_table(pdf)
    # Order items header
    items_header_data = [["ORDER ITEMS"]]
    pdf.table(items_header_data,
      width: pdf.bounds.width,
      cell_style: {
        size: 12,
        font_style: :bold,
        padding: [8, 0],
        borders: [],
        background_color: 'F8F9FA'
      }
    )
    
    pdf.move_down 10
    
    # Items table
    items_data = [
      ["Description", "Size", "Quantity", "Unit Price", "Total (KES)"]
    ]
    
    if @order.order_items.any?
      @order.order_items.includes(:product).each do |item|
        product_name = item.product&.name || "Unknown Product"
        size = item.size || "Standard"
        quantity = item.quantity || 0
        price_per_unit = item.price_per_unit || 0
        total = quantity * price_per_unit
        
        items_data << [
          product_name,
          size,
          quantity.to_s,
          format_price_only(price_per_unit),
          format_price_only(total)
        ]
      end
    else
      items_data << ["No items found", "", "", "", ""]
    end
    
    pdf.table(items_data,
      width: pdf.bounds.width,
      column_widths: [
        pdf.bounds.width * 0.35,  # Description
        pdf.bounds.width * 0.15,  # Size
        pdf.bounds.width * 0.12,  # Quantity
        pdf.bounds.width * 0.19,  # Unit Price
        pdf.bounds.width * 0.19   # Total
      ],
      cell_style: {
        padding: [8, 5],
        borders: [:top, :bottom],
        border_width: 0.5,
        border_color: 'CCCCCC'
      }
    ) do |table|
      # Header row styling
      table.row(0).style(
        font_style: :bold,
        background_color: 'F8F9FA',
        borders: [:top, :bottom],
        border_width: 1
      )
      
      # Align numeric columns
      table.columns(2..4).style(align: :right)
      
      # Data rows styling
      table.rows(1..-1).style(
        size: 10
      )
    end
    
    pdf.move_down 20
    generate_totals_section(pdf)
  end

  def generate_totals_section(pdf)
    subtotal = calculate_subtotal
    total_amount = @order.total_price || subtotal
    
    totals_data = [
      ["", "", "", "Subtotal", format_price_only(subtotal)],
      ["", "", "", "Delivery fee", format_price_only(0)],
      ["", "", "", "Tax (16%)", "Inclusive"],
      ["", "", "", "Total", format_price_only(total_amount)]
    ]
    
    pdf.table(totals_data,
      width: pdf.bounds.width,
      column_widths: [
        pdf.bounds.width * 0.35,
        pdf.bounds.width * 0.15,
        pdf.bounds.width * 0.12,
        pdf.bounds.width * 0.19,
        pdf.bounds.width * 0.19
      ],
      cell_style: {
        padding: [5, 5],
        borders: []
      }
    ) do |table|
      # Right align the totals section
      table.columns(3..4).style(align: :right)
      
      # Subtotal and other lines
      table.rows(0..2).style(size: 10)
      
      # Total line - make it bold and larger
      table.row(3).style(
        size: 12,
        font_style: :bold,
        borders: [:top],
        border_width: 1,
        border_color: '000000'
      )
    end
    
    pdf.move_down 30
  end

  def generate_payment_section(pdf)
    # Payment information in two columns
    payment_left_data = [
      ["Payment Information"],
      ["Payment status: #{@order.payment_status}"]
    ]
    
    company_contact_data = [
      ["Liquor ChapChap"],
      ["Reach out to: +254-717-084-324"],
      ["Email: hello@liquorchapchap.com"]
    ]
    
    # Create a combined table for payment info and company contact
    combined_data = []
    max_rows = [payment_left_data.length, company_contact_data.length].max
    
    (0...max_rows).each do |i|
      left_content = payment_left_data[i] ? payment_left_data[i][0] : ""
      right_content = company_contact_data[i] ? company_contact_data[i][0] : ""
      combined_data << [left_content, right_content]
    end
    
    # Add payment method details
    case @order.payment_status
    when 'Paystack Paid'
      combined_data << ["Payment method: Paystack", ""]
      combined_data << ["Reference: #{@order.paystack_reference}", ""] if @order.paystack_reference
      combined_data << ["Transaction ID: #{@order.paystack_transaction_id}", ""] if @order.paystack_transaction_id
      combined_data << ["Channel: #{@order.paystack_channel&.humanize}", ""] if @order.paystack_channel
    when 'Mpesa Paid'
      combined_data << ["Payment method: M-Pesa", ""]
    when 'Cash on Delivery'
      combined_data << ["Payment method: Cash on Delivery", ""]
      combined_data << ["Amount Due: #{format_currency(@order.total_price)}", ""]
    end
    
    pdf.table(combined_data,
      width: pdf.bounds.width,
      column_widths: [pdf.bounds.width * 0.5, pdf.bounds.width * 0.5],
      cell_style: {
        borders: [],
        padding: [3, 0],
        size: 10
      }
    ) do |table|
      # Style the headers
      table.row(0).style(
        size: 11,
        font_style: :bold
      )
      
      # Right column alignment
      table.column(1).style(align: :left)
    end
    
    pdf.move_down 40
  end

  def generate_footer(pdf)
    footer_data = [["THANK YOU FOR CHOOSING LIQUOR CHAPCHAP"]]
    
    pdf.table(footer_data,
      width: pdf.bounds.width,
      cell_style: {
        size: 12,
        font_style: :bold,
        align: :center,
        padding: [10, 0],
        borders: []
      }
    )
  end

  def calculate_subtotal
    @order.order_items.sum { |item| (item.quantity || 0) * (item.price_per_unit || 0) }
  end

  def format_currency(amount)
    "KES #{sprintf('%.2f', amount.to_f)}"
  end

  def format_price_only(amount)
    sprintf('%.0f', amount.to_f)
  end
end