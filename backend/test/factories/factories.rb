FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@rems.com" }
    name     { "Test User" }
    password { "password123" }
    role     { "tenant" }
    active   { true }

    trait :admin do
      role { "admin" }
      name { "Admin User" }
    end

    trait :clerk do
      role { "clerk" }
      name { "Clerk User" }
    end
  end

  factory :tenant do
    association :user
    phone        { "416-555-0100" }
    company_name { "Test Company" }
  end

  factory :property do
    name    { "Oshawa Centre" }
    address { "419 King St W, Oshawa, ON" }
    manager { "Admin User" }
  end

  factory :unit do
    association :property
    sequence(:unit_number) { |n| "U#{n.to_s.rjust(3, '0')}" }
    size        { 500 }
    rental_rate { 2500 }
    tier        { "standard" }
    purpose     { "retail" }
    status      { "available" }
    available   { true }

    trait :occupied do
      status    { "occupied" }
      available { false }
    end

    trait :premium do
      tier        { "premium" }
      rental_rate { 4000 }
    end
  end

  factory :appointment do
    association :unit
    association :tenant
    scheduled_time { 2.days.from_now.change(hour: 10) }
    status         { "confirmed" }
  end

  factory :application do
    association :tenant
    association :unit
    status           { "pending" }
    application_date { Date.today }
    application_data { { business_type: "Retail" } }
    employment_info  { "Employed full-time" }
  end

  factory :lease do
    association :tenant
    association :unit, :occupied
    start_date     { 1.month.ago.to_date }
    end_date       { 11.months.from_now.to_date }
    rent_amount    { 2500 }
    payment_cycle  { "monthly" }
    discount_rate  { 0 }
    status         { "active" }
  end

  factory :invoice do
    association :lease
    association :tenant
    amount        { 2700 }
    amount_paid   { 0 }
    status        { "unpaid" }
    due_date      { 15.days.from_now.to_date }
    billing_month { Date.today.beginning_of_month }
  end

  factory :maintenance_ticket do
    association :lease
    association :tenant
    association :unit, :occupied
    priority    { "routine" }
    status      { "open" }
    description { "Leaking faucet in sink" }
  end

  factory :payment do
    association :invoice
    association :tenant
    amount         { 2700 }
    payment_method { "online" }
    transaction_id { SecureRandom.hex(10) }
    status         { "approved" }
    processed      { true }
  end
end
