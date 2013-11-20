# Be sure to restart your server when you modify this file.

#ProfitCalculator::Application.config.session_store :cookie_store, key: '_profitCalculator_session'
ProfitCalculator::Application.config.session_store :cookie_store, {
  expire_after: 30.minutes,
}
# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# ProfitCalculator::Application.config.session_store :active_record_store
