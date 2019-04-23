# service will be use for first three table of blue point mortgage bank
class BluePointMortgageService
  def initialize
    @sheet_data          = {}
    @sub_sheet           = nil
    @program_name        = nil
    @primary_key         = ""
    @program_names       = {}
    @initialize_programs = {}
    @program_base_rates  = {}
    @main_key            = nil
  end

  def implement_programs init_row, last_row, row_start_after, strict_rows, main_row, table_first_row, table_last_row, max_column, sheet_data, two_lvl_init_row, two_lvl_final_row, two_lvl_start_points, two_lvl_heading_row, two_lvl_column_limit
    (init_row..last_row).each do |r|
      row = sheet_data.row(r)

      # find sub sheet according to sheet name
      if !@sub_sheet.present? && (SubSheet::SUBSHEETS.include?(row.first))
        @sub_sheet = SubSheet.find_by_name(row.first)
      end

      # row_start_after
      if (r > row_start_after) && @sub_sheet.present?
        # strict_rows
        strict_rows.each do |c|
          @program_base_rates[c] = {}

          if r == table_first_row && strict_rows.include?(c) #table_first_row
            @title = sheet_data.cell(r,c)
            unless @sheet_data.has_key?(@title)
              @sheet_data[@title] = {}
              @program_names[c] = @title
            end
          end

          @main_key = @program_names[c]
          for col in c..c+3
            value = sheet_data.cell(r,col)

            # main_row
            if r > main_row && col >= c && col < c + 3
              if strict_rows.include?(c)
                @program_name = @program_names[c]
                @program = @sub_sheet.programs.new(program_name: @program_name)
                @program.update_fields(@program_name)
                @initialize_programs[c] = @program
              end

              if col == c
                @primary_key = sheet_data.cell(r,col)
                @sheet_data[@main_key][@primary_key] = {}
              elsif col > c && (col < c+3)
                secondary_key = sheet_data.cell(main_row,col)
                @sheet_data[@main_key][@primary_key][secondary_key.to_i] = value
              end
            end

            if c+3 == col
              @program_base_rates[c][@program_names[c]] = @sheet_data[@program_names[c]]
            end
          end

          if c+3 == max_column && r == table_last_row # table_last_row for 119
            @initialize_programs.keys.each do |key|
              program = @initialize_programs[key]
              program.base_rate = @program_base_rates[key][program.program_name]
              program.save
            end
          end
        end
      end
    end

    BluePointService.new().execute(two_lvl_init_row, two_lvl_final_row, two_lvl_start_points, two_lvl_heading_row, two_lvl_column_limit, sheet_data, @sub_sheet)
  end
end
