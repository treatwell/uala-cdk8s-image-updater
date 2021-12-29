#!/usr/bin/env ruby
require 'bundler/setup'
require 'dotenv/load'
require_relative 'app/controllers/updater_controller'

puts "\n############### HI! this is cdk8s-image-updater! #################\n".blue

updater = UpdaterController.new
updater.step_0
updater.step_1
updater.step_2
updater.step_3
updater.step_4
updater.step_5
updater.step_6
updater.step_7

puts "\nDONE!\n".blue