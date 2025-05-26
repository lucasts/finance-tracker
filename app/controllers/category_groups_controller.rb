class CategoryGroupsController < ApplicationController
  before_action :set_category_group, only: [:edit, :update, :destroy]

  def index
    @category_groups = CategoryGroup.order(:name)
  end

  def new
    @category_group = CategoryGroup.new
  end

  def create
    @category_group = CategoryGroup.new(category_group_params)
    if @category_group.save
      redirect_to category_groups_path, notice: "Grupo de categoria criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @category_group.update(category_group_params)
      redirect_to category_groups_path, notice: "Grupo de categoria atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category_group.destroy
    redirect_to category_groups_path, notice: "Grupo de categoria removido."
  end

  private

  def set_category_group
    @category_group = CategoryGroup.find(params[:id])
  end

  def category_group_params
    params.require(:category_group).permit(:code, :name, :role)
  end
end
