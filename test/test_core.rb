require 'test_helper'

class ParanoidTest < ParanoidBaseTest
  def test_paranoid?
    assert !NotParanoid.paranoid?
    assert_raise(NoMethodError) { NotParanoid.delete_all! }
    assert_raise(NoMethodError) { NotParanoid.first.destroy! }
    assert_raise(NoMethodError) { NotParanoid.with_deleted }
    assert_raise(NoMethodError) { NotParanoid.only_deleted }    

    assert ParanoidTime.paranoid?
  end

  def test_fake_removal
    assert_equal 3, ParanoidTime.count
    assert_equal 3, ParanoidBoolean.count
    assert_equal 1, ParanoidString.count

    ParanoidTime.first.destroy
    ParanoidBoolean.delete_all("name = 'paranoid' OR name = 'really paranoid'")
    ParanoidString.first.destroy
    assert_equal 2, ParanoidTime.count
    assert_equal 1, ParanoidBoolean.count
    assert_equal 0, ParanoidString.count
    assert_equal 1, ParanoidTime.only_deleted.count 
    assert_equal 2, ParanoidBoolean.only_deleted.count
    assert_equal 1, ParanoidString.only_deleted.count
    assert_equal 3, ParanoidTime.with_deleted.count
    assert_equal 3, ParanoidBoolean.with_deleted.count
    assert_equal 1, ParanoidString.with_deleted.count
  end

  def test_real_removal
    ParanoidTime.first.destroy!
    ParanoidBoolean.delete_all!("name = 'extremely paranoid' OR name = 'really paranoid'")
    ParanoidString.first.destroy!
    assert_equal 2, ParanoidTime.count
    assert_equal 1, ParanoidBoolean.count
    assert_equal 0, ParanoidString.count
    assert_equal 2, ParanoidTime.with_deleted.count
    assert_equal 1, ParanoidBoolean.with_deleted.count
    assert_equal 0, ParanoidString.with_deleted.count
    assert_equal 0, ParanoidTime.only_deleted.count
    assert_equal 0, ParanoidBoolean.only_deleted.count
    assert_equal 0, ParanoidString.only_deleted.count

    ParanoidTime.first.destroy
    ParanoidTime.only_deleted.first.destroy
    assert_equal 0, ParanoidTime.only_deleted.count

    ParanoidTime.delete_all!
    assert_empty ParanoidTime.all
    assert_empty ParanoidTime.with_deleted.all
  end

  def test_recovery
    assert_equal 3, ParanoidBoolean.count
    ParanoidBoolean.first.destroy
    assert_equal 2, ParanoidBoolean.count
    ParanoidBoolean.only_deleted.first.recover
    assert_equal 3, ParanoidBoolean.count

    assert_equal 1, ParanoidString.count
    ParanoidString.first.destroy
    assert_equal 0, ParanoidString.count
    ParanoidString.with_deleted.first.recover
    assert_equal 1, ParanoidString.count
  end

  def setup_recursive_recovery_tests
    @paranoid_time_object = ParanoidTime.first

    @paranoid_boolean_count = ParanoidBoolean.count

    assert_equal 0, ParanoidHasManyDependant.count
    assert_equal 0, ParanoidBelongsDependant.count

    (1..3).each do |i|
      has_many_object = @paranoid_time_object.paranoid_has_many_dependants.create(:name => "has_many_#{i}")
      has_many_object.create_paranoid_belongs_dependant(:name => "belongs_to_#{i}")
      has_many_object.save

      paranoid_boolean = @paranoid_time_object.paranoid_booleans.create(:name => "boolean_#{i}")
      paranoid_boolean.create_paranoid_has_one_dependant(:name => "has_one_#{i}")
      paranoid_boolean.save

      @paranoid_time_object.not_paranoids.create(:name => "not_paranoid_a#{i}")

    end

    @paranoid_time_object.create_not_paranoid(:name => "not_paranoid_belongs_to")

    @paranoid_time_object.create_has_one_not_paranoid(:name => "has_one_not_paranoid")

    assert_equal 3, ParanoidTime.count
    assert_equal 3, ParanoidHasManyDependant.count
    assert_equal 3, ParanoidBelongsDependant.count
    assert_equal 3, ParanoidHasOneDependant.count
    assert_equal 5, NotParanoid.count
    assert_equal 1, HasOneNotParanoid.count
    assert_equal @paranoid_boolean_count + 3, ParanoidBoolean.count

    @paranoid_time_object.destroy
    @paranoid_time_object.reload

    assert_equal 2, ParanoidTime.count
    assert_equal 0, ParanoidHasManyDependant.count
    assert_equal 0, ParanoidBelongsDependant.count
    assert_equal 0, ParanoidHasOneDependant.count

    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
    assert_equal @paranoid_boolean_count, ParanoidBoolean.count
  end

  def test_recursive_recovery
    setup_recursive_recovery_tests

    @paranoid_time_object.recover(:recursive => true)

    assert_equal 3, ParanoidTime.count
    assert_equal 3, ParanoidHasManyDependant.count
    assert_equal 3, ParanoidBelongsDependant.count
    assert_equal 3, ParanoidHasOneDependant.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
    assert_equal @paranoid_boolean_count + 3, ParanoidBoolean.count
  end

  def test_non_recursive_recovery
    setup_recursive_recovery_tests

    @paranoid_time_object.recover(:recursive => false)

    assert_equal 3, ParanoidTime.count
    assert_equal 0, ParanoidHasManyDependant.count
    assert_equal 0, ParanoidBelongsDependant.count
    assert_equal 0, ParanoidHasOneDependant.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
    assert_equal @paranoid_boolean_count, ParanoidBoolean.count
  end

  def test_deleted?
    ParanoidTime.first.destroy
    assert ParanoidTime.with_deleted.first.deleted?

    ParanoidString.first.destroy
    assert ParanoidString.with_deleted.first.deleted?
  end
  
  def test_paranoid_destroy_callbacks    
    @paranoid_with_callback = ParanoidWithCallback.first
    ParanoidWithCallback.transaction do
      @paranoid_with_callback.destroy
    end
    
    assert @paranoid_with_callback.called_before_destroy
    assert @paranoid_with_callback.called_after_destroy
    assert @paranoid_with_callback.called_after_commit_on_destroy
  end
  
  def test_hard_destroy_callbacks
    @paranoid_with_callback = ParanoidWithCallback.first
    
    ParanoidWithCallback.transaction do
      @paranoid_with_callback.destroy!
    end
    
    assert @paranoid_with_callback.called_before_destroy
    assert @paranoid_with_callback.called_after_destroy
    assert @paranoid_with_callback.called_after_commit_on_destroy
  end

  def test_recovery_callbacks
    @paranoid_with_callback = ParanoidWithCallback.first

    ParanoidWithCallback.transaction do
      @paranoid_with_callback.destroy

      assert_nil @paranoid_with_callback.called_before_recover
      assert_nil @paranoid_with_callback.called_after_recover

      @paranoid_with_callback.recover
    end

      assert @paranoid_with_callback.called_before_recover
      assert @paranoid_with_callback.called_after_recover    
  end

  def test_delete_by_multiple_id_is_paranoid
    model_a = ParanoidBelongsDependant.create
    model_b = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.delete([model_a.id, model_b.id])
    
    assert_paranoid_deletion(model_a)
    assert_paranoid_deletion(model_b)
  end
  
  def test_destroy_by_multiple_id_is_paranoid
    model_a = ParanoidBelongsDependant.create
    model_b = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.destroy([model_a.id, model_b.id])
    
    assert_paranoid_deletion(model_a)
    assert_paranoid_deletion(model_b)
  end
  
  def test_delete_by_single_id_is_paranoid
    model = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.delete(model.id)
    
    assert_paranoid_deletion(model)
  end
  
  def test_destroy_by_single_id_is_paranoid
    model = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.destroy(model.id)
    
    assert_paranoid_deletion(model)
  end
  
  def test_instance_delete_is_paranoid
    model = ParanoidBelongsDependant.create
    model.delete
    
    assert_paranoid_deletion(model)
  end
  
  def test_instance_destroy_is_paranoid
    model = ParanoidBelongsDependant.create
    model.destroy
    
    assert_paranoid_deletion(model)
  end
end
