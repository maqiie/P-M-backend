# db/seeds.rb

# Clear existing data
Tender.delete_all
OngoingProject.delete_all

# Define months and random number range for projects
months = %w[January February March April May June July August September October November December]
min_projects = 5
max_projects = 20

months.each do |month|
  Tender.create!(
    month: month,
    number_of_projects: rand(min_projects..max_projects)
  )

  OngoingProject.create!(
    month: month,
    number_of_projects: rand(min_projects..max_projects)
  )
end

puts "Created #{Tender.count} tenders and #{OngoingProject.count} ongoing projects."
