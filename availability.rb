require "json"
require 'date'

class Availability
  attr_reader :names
  def self.for(*names)
    instance = new *names
    instance.meeting_times
  end

  def initialize(*names)
    @names = names
  end

  def meeting_times
     unless events.any?
      puts "No events found for these users"
      return
    end
    (first_date..last_date).each do |day|
      availabilitys = []
      events_on_date = find_events_on_day(day)
      unless day.strftime("%H:%M") == DateTime.parse(events_on_date.first["start_time"]).strftime("%H:%M")
        availabilitys << [day, events_on_date.first["start_time"]]
      end
      events_processed = []
      until events_processed.count == events_on_date.count
        first_ended_event = if availabilitys.any?
          events_on_date.find { |event| DateTime.parse(event["end_time"]) > datetime_safe_parse(availabilitys.last[1]) }
        else
          events_on_date.first
        end
        other_ongoing_events = events_on_date.filter do |event|
          first_ended_time = DateTime.parse(first_ended_event["end_time"])
          DateTime.parse(event["start_time"]) < first_ended_time &&
          DateTime.parse(event["end_time"]) > first_ended_time
        end
        last_event = other_ongoing_events.any? ? other_ongoing_events.last : first_ended_event
        next_blocking = events_on_date.find { |event| DateTime.parse(event["start_time"]) > DateTime.parse(last_event["end_time"]) }
        available_until = next_blocking.nil? ? DateTime.parse(day.strftime("%Y-%m-%d 17:00")) : DateTime.parse(next_blocking["start_time"])
        availabilitys << [last_event["end_time"], available_until]
        previous_events = events_on_date.filter {|event| DateTime.parse(event["end_time"]) < available_until }
        break unless previous_events.any?
        events_processed.concat(previous_events)
      end
      availabilitys.each { |a| puts build_time_range(a[0], a[1]) }
      print "\n"
    end
  end

private
  def find_events_on_day(day)
    events.filter do |event|
      Date.parse(event["start_time"]).strftime("%Y-%m-%d") == day.strftime("%Y-%m-%d")
    end.sort_by { |event| event["start_time"] }
  end

  def events
    events_json.filter { |event| names.map(&:downcase).include?(get_user(event["user_id"])["name"].downcase) }
  end

  def get_user(user_id)
    users_json.find { |user| user["id"] == user_id }
  end
end

def build_time_range(start_time, end_time)
  "#{datetime_safe_parse(start_time).strftime("%Y-%m-%d %H:%M")} - #{datetime_safe_parse(end_time).strftime("%Y-%m-%d %H:%M")}"
end

def datetime_safe_parse(str_or_datetime)
  str_or_datetime.is_a?(DateTime) ? str_or_datetime : DateTime.parse(str_or_datetime)
end

def last_date
  DateTime.parse("2021-07-07 09:00")
end

def first_date
  DateTime.parse("2021-07-05 09:00")
end

def get_the_json_for(filename)
  json_file = File.open("#{filename}.json").read
  JSON.parse(json_file)
end

def users_json
  get_the_json_for("users")
end

def events_json
  get_the_json_for("events")
end

Availability.for(*ARGV)
