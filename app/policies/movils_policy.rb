class MovilsPolicy < BasePolicy

  def index
    Current.user
  end

  def show
    Current.user
  end

  def method_missing(m, *args, &block)
    Current.user
  end
end
