class TypesController < ApplicationController
  before_filter :authenticate_user!
  authorize_resource

  # GET /types
  # GET /types.json
  def index
    @types = Type.where("NOT pending")
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @types }
      format.csv { render csv: @types }
    end
  end

  def grow
    @types = Type.where("pending")
    respond_to do |format|
      format.html
      format.json { render json: @types }
    end
  end

  def merge
    if params[:id].present?
      from = Type.find(params[:id].to_i)
      from_pending = from.pending
      to = Type.find(params[:into_id].to_i)
      Cluster.where({type_id: from.id}).each{ |from_c|
        to_c = Cluster.where({type_id: to.id, geohash: from_c.geohash, muni: from_c.muni}).first
        # To type doesn't have a cluster here, so just change the type
        if to_c.nil?
          from_c.type_id = to.id
          from_c.save
        # To type does have a cluster here, so merge with from type's cluster
        else
          new_xy = ClusterStuff::move_xy([to_c.x, to_c.y], to_c.count, [from_c.x, from_c.y], from_c.count)
          to_c.x = new_xy[0]
          to_c.y = new_xy[1]
          to_c.count += from_c.count
          to_c.save
          from_c.destroy
        end
      }
      Location.where("? = ANY (type_ids)", from.id).each{ |l|
        l.type_ids = l.type_ids.collect{ |e| e == from.id ? nil : e }.compact
        l.type_ids.push to
        l.save
      }
      from.destroy
      respond_to do |format|
        if from_pending
          format.html { redirect_to grow_types_path, :notice => "Type #{from.id} was successfully merged into type #{to.id}" }
        else
          format.html { redirect_to types_path, :notice => "Type #{from.id} was successfully merged into type #{to.id}" }
        end
        format.json { head :no_content }
      end
    end
  end

  # GET /types/new
  # GET /types/new.json
  def new
    @type = Type.new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @type }
    end
  end

  # GET /types/1/edit
  def edit
    @type = Type.find(params[:id])
    @categories = mask_to_array(@type.category_mask,Type::Categories)
  end

  # POST /types
  # POST /types.json
  def create
    @type = Type.new(params[:type])
    @type.category_mask = array_to_mask(params["categories"],Type::Categories)
    respond_to do |format|
      if @type.save
        # FIXME: Quietly removes parent from children (throw error instead?)
        add_child_ids = s_to_i_array(params[:children_ids]) - s_to_i_array(params[:type][:parent_id])
        add_child_ids.each { |id|
          @child = Type.find(id)
          @child.parent_id = @type.id
          @child.save
        }
        if @type.pending
          format.html { redirect_to grow_types_path, notice: "Type #{@type.id} was successfully created." }
        else
          format.html { redirect_to types_path, notice: "Type #{@type.id} was successfully created." }
        end
        format.json { render json: @type, status: :created, location: @type }
      else
        format.html { render action: "new" }
        format.json { render json: @type.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /types/1
  # PUT /types/1.json
  def update
    @type = Type.find(params[:id])
    from_pending = @type.pending
    params[:type][:category_mask] = array_to_mask(params["categories"],Type::Categories)
    respond_to do |format|
      if @type.update_attributes(params[:type])
        # FIXME: Quietly removes parent from children (throw error instead?)
        new_child_ids = s_to_i_array(params[:children_ids]) - s_to_i_array(params[:type][:parent_id])
        add_child_ids = new_child_ids - @type.children_ids
        remove_child_ids = @type.children_ids - new_child_ids
        add_child_ids.each { |id|
          @child = Type.find(id)
          @child.parent_id = @type.id
          @child.save
        }
        remove_child_ids.each { |id|
          @child = Type.find(id)
          @child.parent_id = nil
          @child.save
        }
        if from_pending
          format.html { redirect_to grow_types_path, notice: 'Type was successfully updated.' }
        else
          format.html { redirect_to types_path, notice: 'Type was successfully updated.' }
        end
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @type.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /types/1
  # DELETE /types/1.json
  def destroy
    @type = Type.find(params[:id])
    @type.destroy
    Cluster.where(type_id: params[:id]).destroy_all
    respond_to do |format|
      format.html { redirect_to :back }
      format.json { head :no_content }
    end
  end
end
