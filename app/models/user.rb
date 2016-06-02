class User < ActiveRecord::Base
  devise :database_authenticatable, :rememberable, :trackable, :validatable,
    :registerable, :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :user_calendars, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :shared_calendars, through: :user_calendars, source: :calendar
  has_many :attendees, dependent: :destroy
  has_many :events
  has_many :invited_events, through: :attendees, source: :event

  after_create :create_calendar

  QUERRY_MY_CALENDAR = "id in (select calendars.id from
    calendars join user_calendars on user_calendars.calendar_id = calendars.id
    where calendars.user_id = ?)"

  QUERRY_OTHER_CALENDAR = "id in (select calendars.id from
    calendars join user_calendars on user_calendars.calendar_id = calendars.id
    where user_calendars.user_id = ? and calendars.user_id <> ?)"

  QUERRY_MANAGE_CALENDAR = "id in (select calendars.id from
    calendars join user_calendars on user_calendars.calendar_id = calendars.id
    where user_calendars.user_id = ? and user_calendars.permission_id IN (?))"

  def my_calendars
    calendars.where QUERRY_MY_CALENDAR, id
  end

  def other_calendars
    Calendar.where QUERRY_OTHER_CALENDAR, id, id
  end

  def manage_calendars
    Calendar.where QUERRY_MANAGE_CALENDAR, id, [1, 2]
  end

  Settings.permissions.each_with_index do |action, permission|
    define_method("permission_#{action}?") do |calendar|
      user_calendars.find_by calendar: calendar, permission_id: permission + 1
    end
  end

  def has_permission? calendar
    user_calendars.find_by calendar: calendar
  end

  def default_calendar
    calendars.find_by is_default: true
  end

  def is_user? user
    self ==  user
  end

  def self.find_for_google_oauth2 access_token, user
    if user
      user.provider = access_token.provider
      user.uid = access_token.uid
      user.token = access_token.credentials.token
      user.save
      user
    end
  end

  private
  def create_calendar
    self.calendars.create({name: self.name, color_id: 1, is_default: true})
  end
end
