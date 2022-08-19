// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


/*
  SELOWORLD IS AN NFT MARKETPLACE FOR AUCTIONING REAL ESTATE TRADED WITH CELO COIN
*/
contract Seloworld is ERC721, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;

    Counters.Counter private _landIdCounter;
    Counters.Counter private _salesmenCounter;

    address internal _Owner;
   
    uint256 private seed;

    // Default auction variables
    uint32 public bidIncreasePercentage;
    uint32 public feePercentage;
    address payable public feeRecepient;


    enum auctionStatus{
      Offer,
      Started,
      Ended
    }

    struct Land {
        address owner;
        uint256 minPrice; 
        uint256 buyPrice;
        uint256 highestBid;
        address highestBidder;
        auctionStatus status;
      }

    mapping(uint256 => Land) public lands; // MAP Land STRUCT TO AN UINT IN lands ARRAY
    mapping (address => bool) public salesMen; 


    mapping( address => uint256 ) public bids;
    
    /*
      AUCTION EVENTS 
    */
    event AuctionStart(
      address owner,
      uint256 minPrice
    );

    event BidMade(
      address bidder,
      uint256 amount
    );


    event AuctionEnd(
      address auctionSettler
    );
    /*
      END AUCTION EVENTS
    */

     /*
      AUCTION MODIFIERS
    */
    
    //REQUIRES MINIMUM PRICE SET FOR AUCTION IS GREATER THAN ZERO
    modifier priceGreaterThanZero(uint256 _minPrice) {
      require(_minPrice > 0, "Price cannot be 0");
      _;
    }
    
    //REQUIRES AUCTION SELLER CANT BID ON OWN AUCTION
    modifier notNftSeller(uint256 _tokenId) {
      require(msg.sender != lands[_tokenId].owner, "Owner cannot bid on own NFT");
      _;
    }

    //REQUIRES BID MADE MEETS ALL STANDARDS 
    modifier bidMeetsRequirements(
      uint _tokenId,
      uint256 _amount
    ) {
      require(
        _doesBidMeetBidRquirements(
          _tokenId,
          _amount
        ), "Not enough to bid"
      );
      _;
    }
    /*
      END AUCTION MODIFIERS
    */



    constructor() ERC721("Seloworld", "SEWD") {
        _Owner = msg.sender; 
        feeRecepient = payable(msg.sender);
        bidIncreasePercentage = 100;
        feePercentage = 15;
        seed = uint (blockhash(block.number - 1)) % 100;

        salesMen[_Owner] = true; //GIVES _Owner PERMISSION TO WRITELAND

        if(salesMen[_Owner] = true){
        _salesmenCounter.increment();
        }
    }

     /*
      CHECK AUCTION FUNCTIONS
      N.B - CALLED IN AUCTION MODIFIERS
    */
    
    function _doesBidMeetBidRquirements(uint256 _tokenId, uint256 _amount)
    internal view returns (bool) {
      uint256 bidIncreaseAmount = (lands[_tokenId].highestBid *
      (10000 + bidIncreasePercentage)) / 10000;
      return (msg.value >= bidIncreaseAmount ||
      _amount >= bidIncreaseAmount);
    }

    // RETURNS THE CALCULATED FEE TO BE PAID 
    function _getPortionOfBid(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
      uint256 highestBid = lands[_tokenId].highestBid;
        return (highestBid * feePercentage) / 10000;
    }

    /*
      END AUCTION CHECK FUNCTIONS
    */

    //HANDLE AUCTION PAYMENTS
    function _payout(
      address _recepient,
      uint256 _amount
    ) internal {
        (bool sent, ) = payable(_recepient).call{value: _amount}("");
        require(sent, "Could not make payment");
      }

    function _settleFees(
      uint256 _tokenId
    ) internal{
      uint256 fee = _getPortionOfBid(_tokenId);
      _payout(
        feeRecepient,
        fee
      );
    }

    /*
      AUCTION FUNCTIONS
    */
    // GIVE USER RIGHT TO ADD NEW AUCTIONS
    // SEED IMITATES AN ACCOUNT LISTING ASSESMENT FOR USERS  
    function GiveRightToAuction (
      address _salesman
    ) public returns (bool) {
      if(seed >=1) {
        salesMen[_salesman] = true;
        _salesmenCounter.increment();
      }
      return (salesMen[_salesman]);
    }

    function CreateAuction(
      string memory _uri,
      uint256 _minPrice,
      uint256 _buyPrice
    ) public  
    priceGreaterThanZero(
      _minPrice
    )
    {
      bool sender = salesMen[msg.sender];
      require(sender != false, "has no right");
      uint tokenId = _landIdCounter.current();
      lands[tokenId].minPrice = _minPrice;
      lands[tokenId].buyPrice = _buyPrice;
      lands[tokenId].owner = msg.sender;
      lands[tokenId].status = auctionStatus.Offer;
      safeMint(msg.sender, _uri);
      transferFrom(msg.sender, address(this), tokenId);
    
      _landIdCounter.increment();

      emit AuctionStart(
       msg.sender,
       _minPrice
      );
    }

  function MakeBid(uint256 _tokenId, uint256 _amount) external payable
   bidMeetsRequirements(
    _tokenId,
    _amount
  ) 
  notNftSeller( 
   _tokenId
  ){
    require(lands[_tokenId].status == auctionStatus.Offer, "Auction has not started");
    require(lands[_tokenId].status != auctionStatus.Ended, "Auction has ended!");
    lands[_tokenId].highestBid = _amount;
    lands[_tokenId].highestBidder = msg.sender;
    lands[_tokenId].status = auctionStatus.Started;

    emit BidMade(
      msg.sender,
      msg.value
    );
  
  }

  function buyAuction( uint _tokenId) public 
  notNftSeller( 
   _tokenId
  ){
    require(lands[_tokenId].status == auctionStatus.Offer, "Auction has not started");
    require(lands[_tokenId].status != auctionStatus.Ended, "Auction has ended!");
    uint256 buyPrice = lands[_tokenId].buyPrice;
    address landOwner = lands[_tokenId].owner;
    address highestBidder = lands[_tokenId].highestBidder;
    _payout(landOwner, buyPrice); 
    transferFrom(address(this), highestBidder, _tokenId);
    
    EndAuction(_tokenId);
  }

  receive() external payable{}

  function GetBalance() public view returns(uint) {
     return address(this).balance;
  } 
  
  function EndAuction(uint256 _tokenId) public {
    require(lands[_tokenId].status == auctionStatus.Started, "Auction has not started");
    require(lands[_tokenId].status != auctionStatus.Ended, "Auction has ended!");
    require(msg.sender == lands[_tokenId].owner, "not owner of auction");
    address highestBidder = lands[_tokenId].highestBidder;
    uint256 highestBid = lands[_tokenId].highestBid;
    address owner = lands[_tokenId].owner;
    uint256 fee = _getPortionOfBid(_tokenId);
    uint256 winningBid = highestBid - fee;
    lands[_tokenId].status = auctionStatus.Ended;
    if(highestBidder != address(0)) {
        _payout(
        owner,
        winningBid
        );
        _settleFees(_tokenId);
        transferFrom(address(this), highestBidder, _tokenId);

        emit AuctionEnd(
          highestBidder
        );

    }

        
  }

  function ReadAuction(uint256 _tokenId) public view returns (
    address,
    uint256,
    uint256,
    address
  ) {
    return (
      lands[_tokenId].owner,
      lands[_tokenId].minPrice,
      lands[_tokenId].highestBid,
      lands[_tokenId].highestBidder
    );
  }

  /*
    END AUCTION FUNCTIONS
  */
  
    function safeMint(address to, string memory uri) public{
        uint256 tokenId = _landIdCounter.current();
        _landIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    // Changes is made to approve to prevent the renter from stealing the token
    function approve(address to, uint256 _tokenId) public override {
        require(
            msg.sender == lands[_tokenId].owner,
            "Caller has to be owner of NFT"
        );
        super.approve(to, _tokenId);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     * Changes is made to transferFrom to prevent the renter from stealing the token
     */
    function transferFrom(
        address from,
        address to,
        uint256 _tokenId
    ) public override {
        require(
            msg.sender == lands[_tokenId].owner,
            "Caller has to be owner of NFT"
        );
        super.transferFrom(from, to, _tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     * Changes is made to safeTransferFrom to prevent the renter from stealing the token
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 _tokenId,
        bytes memory data
    ) public override {
        require(
            msg.sender == lands[_tokenId].owner,
            "Caller has to be owner of NFT"
        );
        _safeTransfer(from, to, _tokenId, data);
    }


    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}