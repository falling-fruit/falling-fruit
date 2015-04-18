class String
  def upcase_first
    self.gsub(/^.{1}/) { |m| m.upcase }
  end
  def downcase_first
    self.gsub(/^.{1}/) { |m| m.downcase }
  end
end