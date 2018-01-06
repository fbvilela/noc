require 'rubygems'
require 'bundler'
Bundler.require

if ENV['RACK_ENV'] == 'development'
  require 'dotenv'
  Dotenv.load
end

require File.expand_path(File.dirname(__FILE__) + '/app')

run App
