# this service will be use for next two tables of blue point bank mortgage sheet
class BluePointService
  def initialize
    @sheet_data          = {}
    @program_name        = nil
    @primary_key         = ""
    @program_names       = {}
    @initialize_programs = {}
    @program_base_rates  = {}
    @main_key            = nil
  end

  def execute init_row, final_row, col_start_points, col_head, max_column, sheet_data, sub_sheet
    (init_row..final_row).each do |r|
      row = sheet_data.row(r)

      if (r > (init_row - 1)) && sub_sheet.present?
        row = sheet_data.row(r)
        col_start_points.each do |c|
          @program_base_rates[c] = {}

          if r == init_row && col_start_points.include?(c)
            @title = sheet_data.cell(r,c)
            unless @sheet_data.has_key?(@title)
              @sheet_data[@title] = {}
              @program_names[c] = @title
            end
          end

          @main_key = @program_names[c]

          for col in c..c+2
            value = sheet_data.cell(r,col)

            # main_row
            if r > col_head && col >= c && col < c + 2
              if col_start_points.include?(c)
                @program_name = @program_names[c]
                @program = sub_sheet.programs.new(program_name: @program_name)
                @program.update_fields(@program_name)
                @initialize_programs[c] = @program
              end

              if col == c
                @primary_key = sheet_data.cell(r,col)
                @sheet_data[@main_key][@primary_key] = {}
              elsif col > c && (col < c+3)
                secondary_key = sheet_data.cell(col_head,col)
                @sheet_data[@main_key][@primary_key][secondary_key.to_i] = value
              end
            end

            if c+2 == col
              @program_base_rates[c][@program_names[c]] = @sheet_data[@program_names[c]]
            end
          end

          if c+2 == max_column && r == final_row # table_last_row for 119
            @initialize_programs.keys.each do |key|
              program = @initialize_programs[key]
              program.base_rate = @program_base_rates[key][program.program_name]
              program.save
            end
          end
        end
      end
    end
  end
end
