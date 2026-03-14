require_relative "template_handler"

module MjmlRb
  class Railtie < Rails::Railtie
    config.mjml_rb = ActiveSupport::OrderedOptions.new
    config.mjml_rb.compiler_options = {validation_level: "strict"}

    initializer "mjml_rb.action_view" do |app|
      MjmlRb.rails_compiler_options = app.config.mjml_rb.compiler_options.to_h

      ActiveSupport.on_load(:action_view) do
        MjmlRb.register_action_view_template_handler!
      end
    end
  end
end
