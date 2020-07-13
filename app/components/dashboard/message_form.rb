module Dashboard
  class MessageForm < ViewComponent::Base
    include Motion::Component
    include SvgHelper # helpers must be included from parent, or included
    include FormsHelper

    attr_reader :message, :hide_to_from

    delegate :content, :from, :to, to: :message, allow_nil: true

    map_motion :submit
    map_motion :validate
    map_motion :dismiss

    def initialize(to:, from:, hide_to_from: false)
      @message = Message.new(from: from, to: to)
      @hide_to_from = hide_to_from
      @touched = []
      @valid = @message.valid?
    end

    ## Map motions
    def submit(event)
      return unless false

      ActionCable.server.broadcast(@reading_message_channel, {id: nil})
    end

    def validate(event)
      message.assign_attributes(message_attributes(event.form_data))
      @touched << event.target.data[:field].to_sym
      @valid = message.valid?
    end

    def dismiss(event)
      return false
    end
    ## End map motions

    def user_options
      User.where.not(id: from)
    end

    def form_status
      return "text-success" if message.valid?

      return "text-primary" if no_errors_for_touched_fields

      "text-warning"
    end

    def no_errors_for_touched_fields
      @touched.all? { |field| message.errors[field].none? }
    end

    def show_disabled_msg
      !no_errors_for_touched_fields
    end

    def disabled
      message.errors.any?
    end

    def message_attributes(params)
      params.require(:message).permit(:to_id, :content)
    end
  end
end