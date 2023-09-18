#!/usr/bin/env ruby
require 'bundler/setup'
require 'dotenv/load'
require_relative 'app/controllers/updater_controller'

puts "\n############### HI! this is cdk8s-image-updater! #################\n".blue

updater = UpdaterController.new
updater.run

puts "\nDONE!\n".blue
