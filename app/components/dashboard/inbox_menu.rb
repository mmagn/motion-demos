module Dashboard
  class InboxMenu < ApplicationComponent
    include Motion::Component
    include SvgHelper

    attr_reader :user, :on_click, :offset, :per_page, :total

    map_motion :change_list

    def initialize(user:, on_click:)
      @user = user
      @on_click = on_click
      set_counts

      stream_messages
    end

    def stream_messages
      stream_from to_message_channel, :count_messages
      stream_from from_message_channel, :count_messages
    end

    def lists
      {
        sent_messages: "sent_messages_count",
        messages: "messages_count"
      }
    end

    def current_count
      instance_variable_get("@#{lists[current_list]}")
    end

    def change_list(event)
      @on_click.call(event.target.data[:list])
    end

    def count_messages
      set_counts
    end

    def set_counts
      lists.each do |list, count|
        instance_variable_set("@#{count}", user.send(list).count)
      end
    end

    def from_message_channel
      "messages:from:#{user_id}"
    end

    def to_message_channel
      "messages:to:#{user_id}"
    end

    def user_id
      user.id
    end
  end
end
