module coke_crypto_rewards::coke_crypto_rewards {
    use sui::event;
    use sui::sui::SUI;
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use std::vector;
    // Errors record
    const E_Not_Valid_Company: u64 = 1;
    const E_Invalid_WithdrawalAmount: u64 = 2;
    const E_Invalid_VoucherText: u64 = 3;
    const E_Declined_Voucher: u64 = 4; // voucher declined when Customer tries to redeem voucher that was not listed
    const E_Invalid_Customer: u64 = 5;
    const E_Invalid_Transfer_Amount: u64 = 6;
    // Structs //
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
        voucher_count: u64, // number of vouchers owned by the customer
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
    // Events //
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
    // Functions //
    // Create a new company
    public entry fun create_company(company_address: address, ctx: &mut TxContext) {
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
            company_address,
        });
        event::emit(CompanyCreated {
            company_id,
        });
    }
    // Company to create a new voucher
    public fun create_voucher(ctx: &mut TxContext, company: &mut Company, text: vector<u8>, value: u64) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        let voucher_uid = object::new(ctx);
        let voucher_id = object::uid_to_inner(&voucher_uid);
        let voucher = Voucher {
            id: voucher_uid,
            company_id: company.id,
            text: string::utf8(text),
            value,
            activated: false,
        };
        vector::push_back(&mut company.vouchers, voucher);
        company.voucher_count = company.voucher_count + 1;
        event::emit(VoucherCreated {
            company_id: company.id,
            voucher_id,
        });
    }
    // Company to activate a voucher
    public fun activate_voucher(ctx: &mut TxContext, company: &mut Company, voucher_index: u64) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        voucher.activated = true;
        event::emit(VoucherActivated {
            company_id: company.id,
            voucher_id: object::uid_to_inner(&voucher.id),
        });
    }
    // Company to deactivate a voucher
    public fun deactivate_voucher(ctx: &mut TxContext, company: &mut Company, voucher_index: u64) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        voucher.activated = false;
        event::emit(VoucherDeactivated {
            company_id: company.id,
            voucher_id: object::uid_to_inner(&voucher.id),
        });
    }
    // company to add funds to the balance
    public entry fun add_funds(ctx: &mut TxContext, company: &mut Company, coin: Coin<SUI>) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        let balance_ = coin::into_balance(coin);
        balance::join(&mut company.balance, balance_);
    }
    // company to withdraw funds from the balance
    public entry fun withdraw_funds(ctx: &mut TxContext, company: &mut Company, amount: u64, recipient: address) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        // check if the company has enough funds to withdraw
        assert!(amount <= balance::value(&company.balance), E_Invalid_WithdrawalAmount);
        let coin = coin::take(&mut company.balance, amount, ctx);
        transfer::public_transfer(coin, recipient);
        event::emit(CompanyWithdrawal {
            company_id: company.id,
            amount,
            recipient,
        });
    }
    // company to add a customer
    public fun add_customer(ctx: &mut TxContext, company: &mut Company, customer_address: address) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        let customer_uid = object::new(ctx);
        let customer_id = object::uid_to_inner(&customer_uid);
        let customer = Customer {
            id: customer_uid,
            company_id: company.id,
            voucher_count: 0,
            customer_address,
        };
        vector::push_back(&mut company.customers, customer);
        company.customer_count = company.customer_count + 1;
        event::emit(CustomerCreated {
            company_id: company.id,
            customer_id,
        });
    }
    // customer tries to redeem a voucher from the company to get the value
    public fun redeem_voucher(ctx: &mut TxContext, company: &mut Company, customer: &mut Customer, voucher_index: u64, voucher_text: vector<u8>) {
        // verify that the customer is making the request
        assert!(tx_context::sender(ctx) == customer.customer_address, E_Invalid_Customer);
        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        // check if the voucher is activated
        assert!(voucher.activated, E_Declined_Voucher);
        // check if Voucher.text is same as that voucher_text
        assert!(voucher.text == string::utf8(voucher_text), E_Invalid_VoucherText);
        // check that the company has enough funds to transfer
        assert!(voucher.value <= balance::value(&company.balance), E_Invalid_Transfer_Amount);
        // Transfer the value of the voucher to the customer
        let transfer_amount = coin::take(&mut company.balance, voucher.value, ctx);
        transfer::public_transfer(transfer_amount, customer.customer_address);
        // deactivate the voucher
        voucher.activated = false;
        // add the count of the voucher to the customer's voucher count
        customer.voucher_count = customer.voucher_count + 1;
        event::emit(VoucherRedeemed {
            company_id: company.id,
            voucher_id: object::uid_to_inner(&voucher.id),
            customer_id: customer.id,
        });
    }
    // company to decline a voucher
    public fun decline_voucher(ctx: &mut TxContext, company: &mut Company, voucher_index: u64) {
        // verify that the company is making the request
        assert!(tx_context::sender(ctx) == company.company_address, E_Not_Valid_Company);
        let voucher = vector::borrow_mut(&mut company.vouchers, voucher_index);
        // deactivate the voucher
        voucher.activated = false;
        event::emit(VoucherDeclined {
            company_id: company.id,
            voucher_id: object::uid_to_inner(&voucher.id),
        });
    }
}