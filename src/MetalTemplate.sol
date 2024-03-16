// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MetalTemplate
 * @version 1.0.0
 *
 * @dev Inherit this contract to create a new Metal Template.
 */

/// @dev An address controlled by metal which receives the fee.
address constant METAL_FEE_RECEIVER = 0x71e1BB6EA5B84E9Aa55691a1E86223d250a18F8F;

/// @dev This fee must be sent to the Metal Admin when charging for a template.
uint96 constant METAL_TEMPLATE_BASE_FEE = 0.00025 ether;

uint8 constant METAL_TEMPLATE_VERSION = 1;

abstract contract MetalTemplate {
    address public metalFeeReceiver = METAL_FEE_RECEIVER;
    uint8 public metalTemplateVersion = METAL_TEMPLATE_VERSION;

    constructor() {
        emit MetalTemplateDeloyed(address(this), METAL_TEMPLATE_VERSION);
    }

    event MetalFeePaid(address indexed payer, uint256 indexed amount);
    event MetalTemplateDeloyed(address indexed template, uint256 indexed version);

    error InsufficientFee();
    error Unauthorized();
    error MetalFeePaymentFailed();

    ///
    ////// NECESSARY FUNCTIONS
    ///
    /// @dev if you want to charge for your template, you must override the following functions:
    ///     1. VIEW: supportedChains()
    ///         should return an array of supported chainIds or `[]` to imply all chains
    ///     2. VIEW: metalTemplateFee()
    ///         a view function for the metal frontend.
    ///         MUST return 0  _OR_  `METAL_TEMPLATE_BASE_FEE + your_fee`.
    ///     3. WRITE: payTemplateFee()
    ///         should be called at the beginning of your template's `deploy()` call
    ///         MUST call _payMetalFee() to transfer some eth to the deployer account.
    ///
    function supportedChains() public view virtual returns (uint256[] memory chainIds);
    function metalTemplateFee() public view virtual returns (uint256 totalFee);
    function payTemplateFee() internal virtual;

    /// @dev This function MUST be called if your template charges a fee.
    function _payMetalFee() internal {
        /// @dev If the template is free, don't charge the user.
        if (metalTemplateFee() == 0) return;
        /// @dev If the user didn't send enough, revert the transaction.
        if (msg.value < METAL_TEMPLATE_BASE_FEE) revert InsufficientFee();

        /// @dev Send the fee to the Metal Admin.
        payable(metalFeeReceiver).transfer(msg.value);
        emit MetalFeePaid(msg.sender, msg.value);
    }

    //
    //// ADMIN FUNCTIONS (non overridable)
    //
    function setMetalFeeReceiver(address _newAdmin) public {
        if (msg.sender != metalFeeReceiver) revert Unauthorized();
        metalFeeReceiver = _newAdmin;
    }
}

///
////// SAMPLE IMPLEMENTATIONS
///

contract FreeTemplateSample is MetalTemplate {
    function metalTemplateFee() public pure override returns (uint256 totalFee) {
        return 0;
    }

    // @dev will implicitly return `[]`
    function supportedChains() public pure override returns (uint256[] memory) {}

    function payTemplateFee() internal override {}
}

contract PaidTemplateSample is MetalTemplate {
    address public immutable creator = 0x00000000000000000000000000000000000A11c3;
    uint256 immutable MY_FEE = 0.01 ether;

    function metalTemplateFee() public pure override returns (uint256 totalFee) {
        totalFee = METAL_TEMPLATE_BASE_FEE + MY_FEE;
    }

    // @dev will implicitly return `[]`
    function supportedChains() public pure override returns (uint256[] memory) {}

    function payTemplateFee() internal override {
        _payMetalFee();
        (bool success,) = creator.call{value: MY_FEE}("");
        if (!success) revert MetalFeePaymentFailed();
    }
}
