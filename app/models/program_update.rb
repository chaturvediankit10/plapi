class ProgramUpdate
  class << self
    def set_term(name)
      if name.downcase.include?("year")
        digit_string  = name.downcase.split("year").first.split(" ").last
        modify_string(digit_string)
      elsif name.downcase.include?("yr")
        digit_string = name.downcase.split("yr").first.last#.scan(/\d/).join('')
        modify_string(digit_string)
      end
    end

    def arm_basic(name)
      arm = nil
      arm = name.split("ARM")
      hiphen_present = arm[0].include?("-")
      slash_present  = arm[0].include?("/")
      if hiphen_present or slash_present
        num = name.split("ARM")[0].gsub!(/[^0-9a-z]/, '')
        if num.length == 2
          num.split("")[0].to_i
        end
      end
    end

    def arm_advanced(name)
      arm = nil
      arm = name.split("ARM")
      hiphen_present = arm[0].include?("-")
      slash_present  = arm[0].include?("/")
      if hiphen_present or slash_present
        num = name.split("ARM")[0].gsub!(/[^0-9a-z]/, '')
        if num.length == 2
          num.insert(-2, '-') if hiphen_present
          num.insert(-2, '-') if slash_present
        end
      end
    end

    private
    def modify_string string
      symbol_arr    = ["-", "/"]
      string_symbol = nil
      string.each_char { |c|
        string_symbol = c if symbol_arr.include?(c)
      }

      if string_symbol.present? && string.include?(string_symbol)
        last_digit   = string.split(string_symbol).last.to_i
        digits_count = MatheMatics.digits(last_digit)
        if digits_count > 1
          string = string.gsub(string_symbol,"").to_i
        else
          string = string.split(string_symbol).first + "0" + string.split("-").last
          string = string.to_i
        end
      else
        string.to_i
      end
    end
  end
end
