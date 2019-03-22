class IntegerQuestion < Question
  field :no_of_digits, type: Integer

  def as_json(with_key: false,with_language_support:false)
    common_data_json(with_key: with_key,with_language_support:with_language_support).merge(no_of_digits: no_of_digits)
  end

  private
  def abstract_class
    false
  end
end
