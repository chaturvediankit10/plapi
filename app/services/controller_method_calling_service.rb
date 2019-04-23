class ControllerMethodCallingService

  def initialize
    @controller = nil
    @method     = nil
    @sheet      = nil
    @files      = Dir.entries("remote_files") # get all files from remote files folder
  end

  def invoke_method
    @files.each do |file|
      if file.split(".").last.present?
        # create object
        file       = File.join(Rails.root.join('remote_files', file))
        # read file
        xlsx       = Roo::Spreadsheet.open(file)

        # remove .xls from file to find controller name
        @controller = file.split("/")[-1].downcase.gsub(".xls", "")
        class_name = @controller.camelize + "Controller"

        #  get sheets names of file
        sheets = xlsx.sheets
        sheets.each do |sheet|
          # get method_name
          @method = sheet.match(/\s/).nil? ? sheet.downcase : sheet.downcase.gsub(" ", "_")

          # get required data
          @class = class_name.include?("OB") ? class_name.gsub("OB", "Ob") : class_name
          @controllers_names = Dir[Rails.root.join('app/controllers/*_controller.rb')].map { |path| (path.match(/(\w+)_controller.rb/); $1).camelize+"Controller" }
          sheet_name = sheet
          # check controller name is exists or not
          if @controllers_names.include?(@class)
            @class     = Object.const_get(@class, Class.new(StandardError))
            # action   = sheet.tableize.singularize
            @sheet     = find_sheet(sheet_name)
            controller = @class.new
            # check methods is present or not in controller
            if controller.methods.include?(@method.to_sym)
              if @sheet
                fetch_location(@sheet)
              else
                hit_index
                @sheet = find_sheet(sheet_name)
                fetch_location(@sheet)
              end
            end
          end
        end
      end
    end
  end

  private

  def find_sheet sheet_name
    return Sheet.find_by_name(sheet_name)
  end

  def fetch_location sheet
    puts "Controller: #{@controller} and Method: #{@method}"
    domain = Rails.env.development? ? "http://localhost:3000" : "https://rate-sheet-extractor.herokuapp.com"
    app = ActionDispatch::Integration::Session.new(Rails.application)
    app.get("#{domain}/#{@controller}/#{sheet.id}/#{@method}")
  end

  def hit_index
    domain = Rails.env.development? ? "http://localhost:3000" : "https://rate-sheet-extractor.herokuapp.com"
    app = ActionDispatch::Integration::Session.new(Rails.application)
    app.get("#{domain}/#{@controller}")
  end
end
