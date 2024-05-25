module coke_crypto_rewards::coke_crypto_rewards {

    use sui::event;
    use sui::sui::SUI;
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    const E_Not_Valid_Company : u64 = 1;
    const E_Invalid_WithdrawalAmount : u64 = 2;
    const E_Invalid_VoucherText : u64 = 3;
    const E_Declined_Voucher : u64 = 4;
    const E_Invalid_Customer : u64 = 5;
    const E_Invalid_Transfer_Amount : u64 = 6;
    const E_Invalid_VoucherIndex : u64 = 7;
    const E_CustomerAlreadyExists : u64 = 8;

    public struct Voucher has key, store {
        id: UID,
        company_id: ID,
        text: String,
        value: u64,
        activated: bool,
    }

    public struct Customer has key, store {
        id: UID,
        company_id: ID,
        voucher_count: u64,
        customer_address: address,
    }

    public struct Company has key {
        id: UID,
        name: String,
        balance: Balance<SUI>,
        vouchers: vector<Voucher>,
        voucher_count: u64,
        customers: vector<Customer>,
        customer_count: u64,
        company_address: address,
    }

    public struct CompanyCreated has copy, drop {
        company_id: ID,
    }

    public struct VoucherRedeemed has copy, drop {
        company_id: ID,
        voucher_id: ID,
        customer_id: ID,
    }

    public struct VoucherActivated has copy, drop {
        company_id: ID,
        voucher_id: ID,
    }

    public struct VoucherDeactivated has copy, drop {
        company_id: ID,
        voucher_id: ID,
    }

    public struct VoucherCreated has copy, drop {
        company_id: ID,
        voucher_id: ID,
    }

    public struct VoucherDeclined has copy, drop {
        company_id: ID,
        voucher_id: ID,
    }

    public struct CustomerCreated has copy, drop {
        company_id: ID,
        customer_id: ID,
    }

    public struct CompanyWithdrawal has copy, drop {
        company_id: ID,
        amount: u64,
        recipient: address,
    }

    public fun create_company(company_address: address, ctx: &mut TxContext) {
        let company_uid = object::new(ctx);
        let company_id = object::uid_to_inner(&company_uid);

        transfer::share_object(Company {
            id: company_uid,
            name: string::utf8(b"Coke Company"),
            balance: balance::zero<SUI>(),
            vouchers: vector::empty(),
            voucher_count: 0,
            customers: vector::empty(),
            customer_count: 0,
            company_address: company_address,
        });

        event::emit(CompanyCreated {
            company_id
        });
    }

    public fun create_voucher(ctx: &mut TxContext, company: &mut Company, company_id: ID, text: vector<u8>, value: u64) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);

        let voucher_uid = object::new(ctx);
        let voucher_id = object::uid_to_inner(&voucher_uid);

        let voucher = Voucher {
            id: voucher_uid,
            company_id,
            text: string::utf8(text),
            value,
            activated: false
        };

        vector::push_back(&mut company.vouchers, voucher);
        company.voucher_count = company.voucher_count + 1;

        event::emit(VoucherCreated {
            company_id,
            voucher_id
        });
    }

    public fun activate_voucher(ctx: &mut TxContext, company: &mut Company, company_id: ID, voucher_index: u64, voucher_id: ID) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        assert!(voucher_index < vector::length(&company.vouchers), E_Invalid_VoucherIndex);

        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        voucher.activated = true;

        event::emit(VoucherActivated {
            company_id,
            voucher_id
        });
    }

    public fun deactivate_voucher(ctx: &mut TxContext, company: &mut Company, company_id: ID, voucher_id: ID, voucher_index: u64) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        assert!(voucher_index < vector::length(&company.vouchers), E_Invalid_VoucherIndex);

        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        voucher.activated = false;

        event::emit(VoucherDeactivated {
            company_id,
            voucher_id
        });
    }

    public fun add_funds(ctx: &mut TxContext, company: &mut Company, coin: Coin<SUI>) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);

        let balance_ = coin::into_balance(coin);
        balance::join(&mut company.balance, balance_);
    }

    public fun withdraw_funds(ctx: &mut TxContext, company: &mut Company, company_id: ID, amount: u64, recipient: address) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        assert!(amount <= balance::value(&company.balance), E_Invalid_WithdrawalAmount);

        let coin = coin::take(&mut company.balance, amount, ctx);
        transfer::public_transfer(coin, recipient);

        event::emit(CompanyWithdrawal {
            company_id,
            amount,
            recipient
        });
    }

    public fun add_customer(ctx: &mut TxContext, company: &mut Company, company_id: ID, customer_address: address) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);

        let mut i = 0;
        while (i < vector::length(&company.customers)) {
            let existing_customer = vector::borrow(&company.customers, i);
            assert!(existing_customer.customer_address != customer_address, E_CustomerAlreadyExists);
            i = i + 1;
        }

        let customer_uid = object::new(ctx);
        let customer_id = object::uid_to_inner(&customer_uid);

        let customer = Customer {
            id: customer_uid,
            company_id,
            voucher_count: 0,
            customer_address,
        };

        vector::push_back(&mut company.customers, customer);
        company.customer_count = company.customer_count + 1;

        event::emit(CustomerCreated {
            company_id,
            customer_id
        });
    }

    public fun redeem_voucher(ctx: &mut TxContext, company: &mut Company, company_id: ID, customer: &mut Customer, customer_id: ID, voucher_id: ID, voucher_text: vector<u8>, voucher_index: u64) {
        assert!(tx_context::sender(ctx) == customer.customer_address, E_Invalid_Customer);
        assert!(voucher_index < vector::length(&company.vouchers), E_Invalid_VoucherIndex);

        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        assert!(voucher.activated, E_Declined_Voucher);
        assert!(voucher.text == string::utf8(voucher_text), E_Invalid_VoucherText);
        assert!(voucher.value <= balance::value(&company.balance), E_Invalid_Transfer_Amount);

        let transfer_amount = coin::take(&mut company.balance, voucher.value, ctx);
        transfer::public_transfer(transfer_amount, customer.customer_address);

        voucher.activated = false;
        customer.voucher_count = customer.voucher_count + 1;

        event::emit(VoucherRedeemed {
            company_id,
            voucher_id,
            customer_id
        });
    }

    public fun decline_voucher(ctx: &mut TxContext, company: &mut Company, company_id: ID, voucher_id: ID, voucher_index: u64) {
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        assert!(voucher_index < vector::length(&company.vouchers), E_Invalid_VoucherIndex);

        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        voucher.activated = false;

        event::emit(VoucherDeclined {
            company_id,
            voucher_id
        });
    }
}
