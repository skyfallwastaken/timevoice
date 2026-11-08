class DocsController < ActionController::Base
  def show
    @scalar = Scalar::Config.instance
  end
end
