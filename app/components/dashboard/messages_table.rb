module Dashboard
  class MessagesTable < ApplicationComponent
    include Motion::Component
    include SvgHelper

    attr_reader :user, :reading, :offset, :per_page, :total

    map_motion :on_paginate

    def initialize(user:, message_type:)
      @user = user
      @message_type = message_type

      @per_page = 10
      @offset = 0
      refresh_query

      stream_messages
    end

    def stream_messages
      stream_from reading_callback.broadcast, :on_reading
      stream_from navigate_callback.broadcast, :on_navigate
      stream_from star_callback.broadcast, :on_star
      stream_from delete_callback.broadcast, :on_delete
    end

    def listen_channels
      ::Messages::Channels.new(messages: @messages, user: user).perform
    end

    ## Callbacks/streaming
    def reading_callback
      @reading_callback ||= bind(:on_reading)
    end

    def on_reading(msg)
      @reading = find_message(msg)
    end

    def navigate_callback
      @navigate_callback ||= bind(:on_navigate)
    end

    def on_navigate(msg)
      direction = msg["navigate"]
      navigate(direction)
    end

    def delete_callback
      @delete_callback ||= bind(:on_delete)
    end

    def on_delete(msg)
      find_message(msg)&.delete!(user)
    end

    def star_callback
      @star_callback ||= bind(:on_star)
    end

    def on_star(msg)
      message = find_message(msg)
      return unless message
      return message.star!(user) unless message.starred?(user)

      if @message_type == :starred_messages
        @messages.delete_if { |m| m.id == message.id }
        refresh_query
      end
      message.unstar!(user)

    end

    def refresh_query
      # stop_streaming_from_user_channels

      @total = message_query.reload.count
      @messages = paginated_message_query

      # start_streaming_from_user_channels
    end
    ## End Callbacks/streaming

    ## Map Motions
    def on_paginate(event)
      action = event.element.data["value"]
      return paginate(@offset + 1) if action == "increase"

      decrease_by = [0, @offset - 1].max
      paginate(decrease_by)
    end
    ## End map motions

    ## Calculated fields
    def on_next_callback
      navigate_callback if navigate_next.present? || paginate_increase?
    end

    def on_previous_callback
      navigate_callback if navigate_previous.present? || paginate_decrease?
    end

    def showing_index
      reading_index + (offset * per_page) + 1
    end

    def messages_start
      offset * per_page + 1
    end

    def messages_end
      [((offset + 1) * per_page), total].min
    end

    def paginate_increase?
      total > ((offset + 1) * per_page)
    end

    def paginate_decrease?
      offset > 0
    end
    ## Calculated fields

    private

    def find_message(msg)
      @messages.find { |m| m.id == msg["id"] }
    end

    def stop_streaming_from_user_channels
      listen_channels.each do |channel|
        stop_streaming_from channel
      end
    end

    def start_streaming_from_user_channels
      listen_channels.each do |channel|
        stream_from channel, :refresh_query
      end
    end

    def reading_index
      @messages.map(&:id).index(reading.id)
    end

    def navigate_next
      @messages[reading_index + 1]
    end

    def navigate_previous
      prev_index = reading_index - 1
      return nil if prev_index < 0

      @messages[prev_index]
    end

    def navigate_in_direction(direction)
      send("navigate_#{direction}")
    end

    def navigate_and_paginate(direction)
      case direction
      when "next"
        paginate(@offset + 1)
        @reading = @messages.first
      when "previous"
        paginate(@offset - 1)
        @reading = @messages.last
      end
    end

    def navigate(direction)
      read_next = navigate_in_direction(direction)
      return @reading = read_next if read_next.present?

      navigate_and_paginate(direction)
    end

    def paginate(new_offset)
      @offset = new_offset
      @messages = paginated_message_query
    end

    def paginated_message_query
      message_query
        .paginated(offset, per_page)
        .eager_load(:from, :to)
        .map { |msg| ::MessageDecorator.new(msg) }
    end

    def message_query
      user.send(@message_type)
    end
  end
end
