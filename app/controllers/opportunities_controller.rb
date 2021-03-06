require 'rubygems'
require 'httparty'
require 'emailhunter'
require "awesome_print"
require "mail"
require 'json'

class OpportunitiesController < ApplicationController

  include HTTParty
  format :json

  def index
    @opportunities = User.find_by_id(current_user.id).opportunities
    @company = Company.find_by_id(params[:id])
  end

  def new
    @current_user_openings =[]
    @company = Company.find_by_id(params[:id])
    @openings = @company.openings
    @opportunities = User.find_by_id(current_user.id).opportunities
    @opportunities.each do |opportunity|
      if opportunity.opening.company_id == @company.id
        @current_user_openings << opportunity
        p "I'm inserted"
      end
    end
    p @current_user_openings
  end

  def create
    @company = Company.find_by_id(params[:id])
    @company.openings.create(opening_params)
    @user = current_user
    @user.openings << @company.openings.last
    @user.opportunities.last.status = "Created"
    redirect_to opportunities_path(current_user)
  end

  def edit
  end

  def update
    @opportunity = Opportunity.find_by_id(params[:id])
    @opportunity.update(opportunity_params)
    redirect_to opportunities_path
  end

  def show
    @opportunity = Opportunity.find_by_id(params[:id])

    @current_user_contacts = []
    @company = Company.find_by_id(params[:company_id])
    @companycontacts = @company.contacts

    @companycontacts.each do |companycontact|
      companycontact.usercontacts.each do |usercontact|
        if usercontact.user_id == current_user.id
          @current_user_contacts << usercontact
        end
      end
    end

    @contact = Contact.new

  end

  def find_email
    p "find email called"

    @opportunity = Opportunity.find_by_id(params[:id])

    @first_name = @opportunity.opening.company.contacts.last.first_name
    @last_name = @opportunity.opening.company.contacts.last.last_name
    @domain = @opportunity.opening.company.website

    params = 'https://api.hunter.io/v2/email-finder?domain='+@domain+'&first_name='+@first_name+'&last_name='+@last_name+'&api_key=0c75c112169e60f02b2a866c22f049492049b278'

    response = HTTParty.get(
      params
    )
    data = response.parsed_response["data"]
    @email = data['email']
    @score = data['score']

    p @email
    p @score
    update_contact

  end

  def update_contact
    p "update contact called"
    @contact =  @opportunity.opening.company.contacts.last
    p @contact
    @contact.update({:email => @email})
    p @contact
  end

  def destroy
    @opportunity = Opportunity.find(params[:id])
    @opportunity.destroy

    redirect_to opportunities_path
  end

  def email_editor

    @opportunity = Opportunity.find_by_id(params[:id])
    @contact = @opportunity.opening.company.contacts.last

    # setting email params
    if params[:inject]

      @key = params.keys[2]
      @params_array = @key.split("\r\n")

      @date =  @params_array[0]
      @message_id = @params_array[1]
      @mime = @params_array[2]
      @type = @params_array[3]
      @transfer = @params_array[4]

      @subject = params[@key][:subject]
      @body = params[@key][:body]
      @to = params[@key][:to]

      @email_string = @date+"\r\nFrom: me\r\nTo: "+@to+"\r\n"+@message_id+"\r\nSubject: "+@subject+"\r\n"+@mime+"\r\n"+@type+"\r\n"+@transfer+"\r\n"+@body

      send_email

    else
      p "you suck"
    end

  end

  def send_email
    p "send email called"

    client = Google::APIClient.new
      client.authorization.access_token = Token.last.fresh_token
      service = client.discovered_api('gmail')
    result = client.execute(
    api_method: service.users.messages.to_h['gmail.users.messages.send'],
    body_object: {
        raw: Base64.urlsafe_encode64(@email_string)
    },
    parameters: {
        userId: 'me',
    },
    headers:   { 'Content-Type' => 'application/json' }
    )
    ap result
    @email = JSON.parse(result.body)
    ap @email
  end

  private

  def opportunity_params
    params.require(:opportunity).permit(:status, :priority)
  end

  def company_params
    params.require(:company).permit(:name, :website, :description)
  end

  def opening_params
    params.require(:opening).permit(:name, :company_id)
  end

  def email_params
    params.permit(:to, :subject, :body)
  end

end
