#!/usr/bin/ruby

$:.unshift File.expand_path('..', __FILE__) + '/lib/'

require 'active_record'
require 'logger'
require 'db'
require 'basecamp'
require 'date'
require 'mechanize'

# config
config = YAML.load_file(File.expand_path('..', __FILE__) + "/config/bcproj.config")

# logging
logger = Logger.new(File.expand_path('..', __FILE__) + "/" + config['logger']['file'])
logger.level = eval(config['logger']['level'])
logger.debug config.inspect

# database
DB.initdb

# date stuff
servernow = DateTime.now()
fulloffset = servernow.offset()+Rational(config['timezoneoffset'],24)
today = servernow.new_offset(fulloffset)
bctoday = today.strftime('%Y%m%d')
bcfrom = Date.new(today.year, today.month, 1).strftime('%Y%m%d')
daysinmonth = (Date.new(Time.now.year,12,31).to_date<<(12-Time.now.month)).day
dayssincebegin = today - Date.new(today.year, today.month, 1)
logger.debug "TODAY: " + today.to_s
logger.debug "BCTODAY: " + bctoday.to_s
logger.debug "BCFROM: " + bcfrom.to_s
logger.debug "DAYSINMONTH: " + daysinmonth.to_s
logger.debug "DAYSSINCEBEGIN: " + dayssincebegin.to_s

# Connect to BC
bc = Basecamp.establish_connection!(config['url'], config['user'], config['password'], true)

# get the report for this month
entries = Basecamp::TimeEntry.report(:to => "#{bctoday}", :from => "#{bcfrom}", :project_id => config['project_id'])
logger.debug "ENTRIES: " + entries.inspect
# get the total time spent
total_time = 0.0
entries.each do |e|
  total_time += e.hours.to_f
end

# Add in the rollover hours (if any) from the previous month
total_time += config['rolloverhours']
total_time -= config['hoursgratis']
logger.debug "TOTAL_TIME: " + total_time.to_s

actualcontracthours = config['contracthours'].to_f + config['additionalhours'].to_f

hourspercentage = (total_time/actualcontracthours)*100
elapsedpercentage = (dayssincebegin/daysinmonth)*100
burnrate = (hourspercentage/elapsedpercentage)*100
hoursdifference = total_time-((elapsedpercentage/100)*actualcontracthours)
burnratestyle = "ontrack"
if burnrate > 105
  burnratestyle = "closehigh"
end
if burnrate < 95
  burnratecolor = "closelow"
end
if burnrate > 110
  burnratecolor = "midhigh"
end
if burnrate < 90
  burnratecolor = "midlow"
end
if burnrate > 120
  burnratecolor = "farhigh"
end
if burnrate < 80
  burnratecolor = "farlow"
end

timenowpst = DateTime.new(today.year, today.month, today.day,
(today.hour), today.min, today.sec)

# just in case there are rollover hours
rollovernotice = ""
if (config['rolloverhours'] != 0) then 
  rollovernotice = " (including #{config['rolloverhours'].round(2)} rollover hours)"
end

# just in case there are any hours gratis
hoursgratisnotice = ""
if (config['hoursgratis'] != 0) then
  if (rollovernotice != "") then
    noticeconnector = " and"
  else
    noticeconnector = ""
  end
  hoursgratisnotice = "#{noticeconnector} (excluding #{config['hoursgratis'].round(2)} hours free of charge)"
end

# just in case there are additional hours
additionalnotice = ""
if (config['additionalhours'] != 0) then
  additionalnotice = " (including #{config['additionalhours']} additonal approved hours)"
end

# just in case the burnrate is not exactly 100%
hoursdiffnotice = ""
if (hoursdifference > 0) then
  hoursdiffnotice = " We are <b>#{hoursdifference.round(2)}</b> hours ahead."
end
if (hoursdifference < 0) then
  hoursdiffnotice = " We need to do <b>#{hoursdifference.abs.round(2)}</b> hours to catch up."
end

# build the announcement
announcement = "
<h2>IMPORTANT NOTICE:</h2>As of #{Date::MONTHNAMES[today.month]} #{today.day}, #{today.year} #{timenowpst.strftime('%H:%M:%S')}, total hours are at <b>#{total_time.round(2)}</b>#{rollovernotice}#{hoursgratisnotice}. This is #{sprintf('%.2f', hourspercentage)}% of the current contract hours of <b>#{actualcontracthours.to_i}</b>#{additionalnotice}. Current burn rate is <span style=\"color: #{config['colors'][burnratestyle]['foreground']};font-weight:bold;background-color: #{config['colors'][burnratestyle]['background']}\">#{sprintf('%.2f', burnrate)}%</span>.#{hoursdiffnotice}"

logger.debug "ANNOUNCE: " + announcement

# post the announcement
agent = Mechanize.new
p = agent.get 'https://aisltd.basecamphq.com/login'
logger.debug p.inspect
f = p.form_with(:action => 'https://launchpad.37signals.com/authenticate')
logger.debug f

f.field_with(:name => 'username').value = config['user']
f.field_with(:name => 'password').value = config['password']
f.submit
p = agent.get "https://aisltd.basecamphq.com/projects/#{config['project_id']}/edit"
logger.debug p.inspect
f = p.form_with(:action => "/projects/#{config['project_id']}")
logger.debug f.inspect
f.field_with(:name => 'settings[project][show_announcement]').value=1
f.field_with(:name => 'settings[project][announcement]').value = announcement
f.submit

