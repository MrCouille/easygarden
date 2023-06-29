require 'net/http'
require 'json'
require 'awesome_print'
# require_relative '../helpers/implant'

class GardensController < ApplicationController
  before_action :set_garden, only: [:show, :destroy, :created, :implant, :implanted, :set_vegetables_for_weather, :validate]
  before_action :set_vegetables_for_weather, only: [:implant]
  COMP_W = 1.2
  IMP_L = 1
  ALLEY_W = 0.3

  def index
    @gardens = Garden.all
  end

  def show
    @quantity_hash = Hash.new(0)
    @garden.compartments.each do |comp|
      comp.implantations.each do |imp|
        vegetable_name = imp.vegetable.name
        quantity = imp.quantity
        unitary_price = imp.vegetable.prix_unitaire
        if @quantity_hash.key?(vegetable_name)
          @quantity_hash[vegetable_name][:quantity] += quantity
        else
          @quantity_hash[vegetable_name] = { quantity: quantity, unitary_price: unitary_price }
        end
      end
    end
  end

  def new
    @garden = Garden.new
  end

  def create
    @garden = Garden.new(garden_params)
    @garden.user = current_user
    if @garden.valid?
      # Calculate number of compartments
      n = number_of_compartments(@garden.width)
      i = 0
      while (i <= n) do
        @garden.compartments.new
        i += 1
      end
      if @garden.save!
        redirect_to created_garden_path(@garden)
        flash.notice = "Garden succesfully created!"
      else
        flash.alert = "Error in creating garden..."
        render :new, status: :unprocessable_entity
      end
    else
      flash.alert = "Error in creating garden..."
      render :new, status: :unprocessable_entity
    end
  end

  def created
    gps_coords = get_gps_coord(@garden.address)
    mean_temp = get_mean_temp(gps_coords[0], gps_coords[1])
    @garden.update(mean_temperature: mean_temp)
    @suitable_vegetables = set_vegetables_for_weather

    # Excluding cannabis for demo day joke
    @suitable_vegetables = @suitable_vegetables.excluding(Vegetable.find_by_name("Cannabis"))
  end

  def implant
    if params[:array_of_veggie].present?
      @array_of_veggie = params[:array_of_veggie]
    else
      @choices = params.select { |key| key.to_s.match("vegetable") }
      @array_of_veggie = @choices.values
    end
    @implantation = get_synergies(@array_of_veggie, @vegetables_for_weather, @garden.length)
    redirect_to implanted_garden_path(@garden, array_of_veggie: @array_of_veggie, implantation: @implantation, counter: @implantation.first.count)
  end

  def implanted
    @implantation = restructure_implantation_array(params["implantation"], params["counter"])
  end

  def destroy
    @garden.destroy
    redirect_to gardens_path
  end

  def validate
    implantations = restructure_implantation_array(params["implantation"], params["counter"])
    validate_garden(@garden, implantations)
    redirect_to garden_path(@garden)
  end

################################ PRIVATE METHODS ########################################
  private
#########################################################################################


####### Garden creation ##########
  def set_garden
    @garden = Garden.find(params[:id])
  end

  def garden_params
    params.require(:garden).permit(:length, :width, :address, :name, :choices)
  end

  def number_of_compartments(garden_width)
    comp_num = (garden_width + ALLEY_W) / (COMP_W + ALLEY_W)
    comp_num.to_i
  end

####### weather ##########
  def get_gps_coord(address)
    output = []
    result = Geocoder.search(address).first
    if result
      latitude = result.latitude
      longitude = result.longitude
      output = [latitude, longitude]
    end
    output
  end

  def get_mean_temp(latitude, longitude)
    result = nil

    # API endpoint URL
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&past_days=92&forecast_days=16&timezone=Europe%2FLondon"

    # Make an HTTP GET request to the API
    response = Net::HTTP.get(URI(url))

    # Parse the JSON response
    data = JSON.parse(response)

    # Extract temperature data and calculate averages
    if data['daily']
      max_temp = data['daily']['temperature_2m_max']
      min_temp = data['daily']['temperature_2m_min']
      max_mean_temp = max_temp.inject { |sum, el| sum + el }.to_f / max_temp.size
      min_mean_temp = min_temp.inject { |sum, el| sum + el }.to_f / min_temp.size
      mean_temp = (max_mean_temp + min_mean_temp) / 2
      result = mean_temp.truncate(2)
    end
    result
  end

  def set_vegetables_for_weather
    mean_temp = @garden.mean_temperature
    @vegetables_for_weather = []
    Vegetable.all.each do |vegetable|
      if mean_temp > vegetable.min_temp && mean_temp < vegetable.max_temp
        @vegetables_for_weather.append(vegetable)
      end
    end
    @vegetables_for_weather
  end


  ####### Garden implantation ##########
  def number_of_implantations(garden_length)
    imp_num = garden_length
    imp_num.truncate
  end

  def get_synergies(chosen_vegetables, vegetables_for_weather, garden_length)
    vegetables_array = get_veg_array(chosen_vegetables)
    number_of_implants = get_number_of_implants(garden_length)
    implantation = []
    p vegetables_array
    vegetables_array.each_with_index do |vegetable, n|
      implantation[n] = []
      implantation[n][0] = vegetable
      i = 0
      while (i < number_of_implants - 1) do
        suitable_vegetables = get_list_of_synergies(vegetable, vegetables_for_weather)
        implantation[n][i + 1] = suitable_vegetables[i]
        i += 1
      end
    end
    implantation
  end

  def get_number_of_implants(garden_length)
    min_length = 3
    garden_length > min_length ? 3 : 2
  end

  def get_list_of_synergies(vegetable_name, vegetables_for_weather)
    result = []
    vege_for_weather_names = get_vege_names(vegetables_for_weather)
    vegetable_id = Vegetable.find_by(name: vegetable_name)
    return if vegetable_id.nil?

    Synergy.for_vegetable(vegetable_id).each do |synergy|
      first_vege = synergy.first_vegetable.name
      second_vege = synergy.second_vegetable.name
      vege = first_vege == vegetable_name ? second_vege : first_vege
      result.append(vege) if vege_for_weather_names.include?(vege)
    end
    result.shuffle
  end

  def get_vege_names(vegetables)
    result = []
    vegetables.each do |vege|
      result.append(vege.name)
    end
    result
  end

  def validate_garden(garden, implantations)
    imp_with_qty = assign_quantities(implantations, garden.length, COMP_W)
    garden.compartments.each_with_index do |comp, c|
      i = 0
      until i == imp_with_qty[0].count
        comp.implantations.new(
          vegetable: Vegetable.find_by(name: imp_with_qty[c][i][:name]),
          quantity: imp_with_qty[c][i][:qty]
        )
        comp.save
        i += 1
      end
    end
  end

  def assign_quantities(implantations, garden_length, comp_width)
    imp_with_qty = []
    number_of_implants = implantations[0].count

    implantations.each_with_index do |compartment, c|
      imp_with_qty[c] = []
      compartment.each_with_index do |vegetable, i|
        implant_length = garden_length / number_of_implants
        implant_area = (implant_length * comp_width)
        qty = get_quantity(vegetable, implant_area)
        imp_with_qty[c][i] = { name: vegetable, qty: }
      end
    end
    imp_with_qty
  end

  def get_quantity(vegetable_name, implant_area)
    vegetable = Vegetable.find_by(name: vegetable_name)
    return if vegetable.nil?

    footprint = vegetable.footprint
    (implant_area / footprint)
  end

  def article_params
    params.require(:article).permit(:title, :body, :photo)
  end


########### Miscellanous Methods ###########################

  # Generate an array of names from a string containing #ids
  def get_veg_array(chosen_vegetables)
    arr = chosen_vegetables.split(",")
    result = []
    arr.each do |veg_id|
      veg = Vegetable.find_by(id: veg_id).name
      result.append(veg)
    end
    result
  end

  # Regenerate a bi-dimensional array from the flattened one sent through params
    def restructure_implantation_array(implantation, counter)
      restructured_implantation = []
      flat_implant = implantation.flatten
      flat_implant.each_slice(counter.to_i) do |compartment|
        restructured_implantation << compartment
      end
      return restructured_implantation
    end

end
