class FibIntegerQuestion < Question
  DASH = '#DASH#'

  field :no_of_int_digits, type: Integer, default: 2
  field :no_of_decimal_digits, type: Integer, default: 2

  embeds_many :question_fill_blanks, cascade_callbacks: :true
  validate :dash_presence
  validates_presence_of :question_fill_blanks
  validate :number_of_fill_blanks
  accepts_nested_attributes_for :question_fill_blanks

  def blanks_count
    question_text.scan(DASH).length
  end

  def as_json(with_key: false,with_language_support:false)
    final_data = common_data_json(with_key: with_key,with_language_support:with_language_support).merge(blanks: question_fill_blanks.map{|b| b.as_json(with_key: with_key,with_language_support:with_language_support)}).merge(no_of_int_digits:no_of_int_digits,no_of_decimal_digits:no_of_decimal_digits)
    JSON.parse(final_data.to_json)
  end

  private
  def dash_presence
    # errors.add(:question_text, 'No #DASH# present') unless blanks_count>0
  end

  def number_of_fill_blanks
    # errors.add(:question_fill_blanks, 'No of dashes mismatch') unless blanks_count==question_fill_blanks.length
  end

  def abstract_class
    false
  end
end
