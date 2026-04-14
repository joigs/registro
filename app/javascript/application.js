// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo"

// Use extended Action Cable protocol to support reliable streams and presence
// See https://github.com/anycable/anycable-client
// Prevent frequent resubscriptions during morphing or navigation

import "controllers"
import "@rails/request.js"
import "custom/companion"

import Swal from 'sweetalert2';
import 'flowbite';

window.Swal = Swal;
