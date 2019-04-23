class MatheMatics

  class << self
    def digits(num)
      return Math.log10(num.to_i).to_i + 1
    end
  end
end
