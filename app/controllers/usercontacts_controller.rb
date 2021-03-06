require 'rubygems'
require 'httparty'
require 'emailhunter'
require "awesome_print"
require "mail"
require 'json'

class UsercontactsController < ApplicationController

    def index
      @user = current_user

      @events = []
      @tasks = Usercontact.all
      @tasks.each do |task|
        if task.summary != nil
          @events << task
        end
      end
      @events.reverse!
    end

    def new
      @company = Company.find_by_id(params[:id])
    end

    def create

      if params[:save]
        @company = Company.find_by_id(params[:company_id])
        p @company
        @company.contacts.create(contact_params)
        @user = current_user
        @user.contacts << @company.contacts.last

        redirect_to opportunities_path
        p "add usercontact"

      else
        @contact = Contact.find_by_id(params[:contact_id])

        p @contact

        # @contact.usercontacts.create(task_params)

        Usercontact.create( user_id: current_user.id, contact_id: @contact.id, summary: task_params[:summary], location: task_params[:location], start: task_params[:start], end: task_params[:end] )

        add_task

        redirect_to '/tasks'

      end
    end

    def add_task
      p 'creating calendar event!'
      @task = Usercontact.last
      # initializing client
      client = Google::APIClient.new
      client.authorization.access_token = Token.last.fresh_token
      service = client.discovered_api('calendar','v3')
      # determining parameter for specific gapi!!
      # client.discovered_apis.each do |gapi|
      #   puts "#{gapi.title} \t #{gapi.id} \t #{gapi.preferred}"
      # end
      calendarId = 'primary'
      g_event = {
        summary: @task.summary,
        location: @task.location,
        start: {dateTime: (@task.start+"T23:59:59+0000").to_s},
      end: {dateTime: (@task.end+"T23:59:59+0000").to_s},
        description: @task.description,
      }
      response = client.execute(:api_method => service.events.insert,
      :parameters => {'calendarId' => calendarId,
      'sendNotifications' => true},
      :body => JSON.dump(g_event),
      :headers => {'Content-Type' => 'application/json'})

      @new_event= JSON.parse(response.body)
    end

    def destroy
      @task = Usercontact.find(params[:id])
      @task.destroy
      redirect_to tasks_path
    end

    private

    def contact_params
      params.require(:contact).permit(:first_name, :last_name, :email)
    end

    def task_params
      params.require(:usercontact).permit(:summary, :location, :start, :end, :description)
    end

end
