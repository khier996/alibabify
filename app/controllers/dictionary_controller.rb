class DictionaryController < ApplicationController

  def initialize
    @dict = Dictionary.new
  end

  def complete
    prefix = params[:prefix]
    results = @dict.complete(prefix, 20)
    render json: {results: results}
  end

  def edit_entry
    original = params[:original]
    translation = params[:translation]
    old_translation = params[:old_translation]
    result = @dict.edit_entry(original, translation, old_translation)

    if result == true
      render json: {original: original, translation: translation}, status: 200
    else
      render nothing: true, status: 400
    end
  end
end
