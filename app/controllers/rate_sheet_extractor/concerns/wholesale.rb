module Wholesale
	def make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
	 	@programs_ids = []
	 	@xlsx.sheets.each do |sheet|
    	sheet_data = @xlsx.sheet(sheet)
      (start_range..end_range).each do |r|
        row = sheet_data.row(r)
        if ((row.compact.count >= count1) && (row.compact.count <= count2))
          rr = r + 1
          max_column_section = row.compact.count - 1
          (0..max_column_section).each do |max_column|
            cc = num1*max_column + num2
            begin
              @title = sheet_data.cell(r,cc)
              if @title.present?
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @programs_ids << @program.id
                Program.new().update_fields @title
                @block_hash = {}
                key = ''
                (r >= cl1 && r <= cl2) ? cl = (cl2-cl1-1) : (r >= cl3 && r <= cl4) ? cl = (cl4-cl3-1) : (r >= cl5 && r <= cl6) ? cl = (cl6-cl5-1) : cl = 20
                (1..cl).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash)
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
      end
	  end
 	end

 	# def program_property
 	# 	# term
  #   if @title.scan(/\d+/).count == 1
  #     term = @title.scan(/\d+/)[0]
  #   elsif @title.scan(/\d+/).count > 1 && !@title.include?("ARM")
  #     term = (@title.scan(/\d+/)[0]+ @title.scan(/\d+/)[1]).to_i
  #   end
  #   # Arm Basic
  #   if @title.include?("ARM")
  #   	arm_basic = @title.scan(/\d+/)[0]
  #   end
  #   # Loan Size
  #   if @title.include?("HIGH BAL") || @title.include?("HIGH BALANCE")
  #     loan_size = "High Balance"
  #     jumbo_high_balance = true
  #   elsif @title.include?("CONFORMING")
  #   	loan_size = "CONFORMING"
  #   	conforming = true
  #   end
  #   # Loan-Type
  #   if @title.include?("Fixed") || @title.include?("FIXED")
  #     loan_type = "Fixed"
  #   elsif @title.include?("ARM")
  #     loan_type = "ARM"
  #   elsif @title.include?("Floating")
  #     loan_type = "Floating"
  #   elsif @title.include?("Variable")
  #     loan_type = "Variable"
  #   else
  #     loan_type = nil
  #   end
  #   # Streamline Vha, Fha, Usda
  #   if @title.include?("FHA")
  #     fha = true
  #   end
  #   if @title.include?("VA")
  #     va = true
  #   end
  #   if @title.include?("USDA")
  #     usda = true
  #   end
  #   if @title.include?("STREAMLINE")
  #     streamline = true
  #   end
  #   # update program
  #   @program.update(term: term, loan_type: loan_type, loan_size: loan_size, fha: fha, va: va, usda: usda, streamline: streamline, jumbo_high_balance: jumbo_high_balance, arm_basic: arm_basic, conforming: conforming)
 	# end
end