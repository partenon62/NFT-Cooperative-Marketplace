
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

//@dev find general idea in 'NFT_Marketplace_Functons'
//@dev Look at supported general idea in : "https://github.com/partenon62/polygon-ethereum-nextjs-marketplace/"

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "hardhat/console.sol";

contract NFTcoopratedMarket is ReentrancyGuard, Ownable, ERC721URIStorage {
/*********************************General_stuffs************************ */   
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _tokenIds; 
    Counters.Counter private _itemsSold;
    Counters.Counter private _cooperationIds;
    Counters.Counter private _candiNum;
    Counters.Counter private _cooperNum;

    mapping(uint256 => bool) idToItemListed;
    address payable Owner;

    uint256 listingPrice = 0.01 ether;
    uint256 coListingPrice = 1 ether;
    uint256 candidateFee = 0.001 ether;
    

    constructor() ERC721("Metaverse Tokens", "METT") {
      Owner = payable(msg.sender);
    }
/*********************************Main_variables************************ */   

    struct Cooperation {
        uint coopId;
        address coopManager;        
        uint nftOwnerShare;
        uint nftCoopShare;
        uint256 minCoopPrice;
        candidate[] candidates;
        Cooperator[] Cooperators;
        MarketItem[] MarketItems;
    }

    struct candidate {
        uint256 candidateId;
        address candidateAddress;
        uint256 coopId;
        string description;
        uint256 pVote;
        uint256 nVote;
        bool accepted;
    }

    struct Cooperator {
        uint cooperId;
        address payable coopAddress;
    }    
    
    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
        bool listed; //added for future features
    }

    Cooperation[] public Cooperations;

/*********************************Main_events*************************** */ 
    event cooperationUpdated (
        uint indexed coopId,
        address indexed Updator,
        uint indexed tokenId,
        uint _price,
        bool  soled,
        bool listed      
    );

/*********************************NFT_Cooperation_Functons************** */ 
    //Create  a new cooperation 
    function createCooperation(
        uint nftOwnerShare_,         //Share ratio for owner of nft between 1 to 99.
        uint256 minCoopPrice_       // minimum price for each nft set by coopManager
    ) public payable returns (uint256) {
        require(msg.value == coListingPrice, "Price must be equal to co-Listing price");
        require(1 <= nftOwnerShare_ && nftOwnerShare_ <= 99, "Range of Shares rates from 1 to 99");

        _cooperationIds.increment();
        uint256 coopId_ = _cooperationIds.current();

        _cooperNum.increment();
        uint256 newCooperNum = _cooperNum.current();

        _candiNum.increment();
        uint256 newCandiNum = _candiNum.current();

        _itemIds.increment();
        uint256 newItemIds = _itemIds.current();

        payable(Owner).transfer(coListingPrice);
        
        //create and update cooperator's mapping
        Cooperations[coopId_].Cooperators[newCooperNum] = Cooperator (
            newCooperNum,
            payable(msg.sender)
        );
        
        candidate storage newCandidate = Cooperations[coopId_].candidates[newCandiNum];
        Cooperations[coopId_].candidates.push(newCandidate);

        MarketItem storage newMarketItem = Cooperations[coopId_].MarketItems[newItemIds];
        Cooperations[coopId_].MarketItems.push(newMarketItem);
        
        Cooperations[coopId_].coopId = coopId_;
        Cooperations[coopId_].coopManager = payable(msg.sender);        
        Cooperations[coopId_].nftOwnerShare = nftOwnerShare_;
        Cooperations[coopId_].nftCoopShare = 100 - nftOwnerShare_;
        Cooperations[coopId_].minCoopPrice = minCoopPrice_;

        return coopId_;
    }

    function requestForCoop(uint256 coopId_, string memory _description ) public payable returns(uint256) {
        require(msg.value == candidateFee, "value must be equal to candidateFee price");
        _candiNum.increment();
        uint256 CandidateId_ = _candiNum.current();
        payable(Owner).transfer(candidateFee);

        Cooperations[coopId_].candidates[CandidateId_] = candidate (
            CandidateId_,
            payable(msg.sender),
            coopId_,
            _description,
            0,
            0,
            false
        );
        return CandidateId_;
    }

    function approveCandidate(uint256 coopId_, uint256 _candidateId, uint256 _Vote) public payable nonReentrant{
        require(_Vote == 1 || _Vote == 0, "Vote must be 1 or 0.");
        require(coopId_ <= _cooperationIds.current(), "Cooperation Id not available");
        require(_candidateId <= _candiNum.current(), "Candidate Number is not available");

        uint256 CoopersNum = _cooperNum.current();
        for(uint256 i = 0; i <= CoopersNum; i++) {
            if (Cooperations[coopId_].Cooperators[i].coopAddress == msg.sender) {
                if (_Vote == 1) {
                    uint256 positiveVote = Cooperations[coopId_].candidates[i].pVote ++;
                    if (positiveVote >= CoopersNum / 2 ) {
                        _cooperNum.increment();
                        uint256 newCooperNum =  _cooperNum.current();
                        address cooperAddress = Cooperations[coopId_].candidates[_candidateId].candidateAddress;
                        Cooperations[coopId_].Cooperators[newCooperNum] = Cooperator (
                            newCooperNum,
                            payable(cooperAddress)
                        );
                        
                        delete Cooperations[coopId_].candidates[_candidateId];
                    }
                } else {
                    uint256 negativeVote = Cooperations[coopId_].candidates[i].nVote ++;
                    if (negativeVote > CoopersNum / 2 ) {
                        delete Cooperations[coopId_].candidates[_candidateId];
                    }
                }
            }
        }
    }

    //Add an Item to Cooperation
    function addMarketItemToCooperation(
        uint256 coopId_,
        uint256 _tokenId,
        uint256 _price
    ) public payable {
        require(_price > Cooperations[coopId_].minCoopPrice, "Price must be bigger than the cooperation minimum price");
        //require(idToCoopList[_coopId].idTocooperator_s[_cooperId].coopAddress == msg.sender, "Updator must be in the Cooperators list"); // replaced by for loop.
        require(msg.value == listingPrice, "Value must be equal to listing price");
        require( Cooperations[coopId_].MarketItems[_tokenId].listed == false, "Token listed before!");
        require(idToItemListed[_tokenId] == false, "Token listed before!");

        uint256 CoopersNum = _cooperNum.current();
        for (uint256 i = 0; i <= CoopersNum; i++) {
            if (Cooperations[coopId_].Cooperators[i].coopAddress == msg.sender ) {
                _itemIds.increment();
                uint256 newMarketItem = _itemIds.current();
                Cooperations[coopId_].MarketItems[newMarketItem] =  MarketItem(
                    _tokenId,
                    payable(msg.sender),
                    payable(address(this)),
                    _price,
                    false,
                    true
                );

                payable(Owner).transfer(listingPrice);
                _transfer(msg.sender, address(this), _tokenId);
                idToItemListed[_tokenId] == true;

                emit cooperationUpdated(
                    coopId_,
                    msg.sender,     
                    _tokenId,
                    _price,
                    false,
                    true
                );                
            }
        }
    }

    //sale item in cooperation
    function saleItemIncooperation(uint256 coopId_, uint256 _tokenId) public payable returns (bool) {
        require(Cooperations[coopId_].MarketItems[_tokenId].listed == true, "Item not listed yet");
        uint price = Cooperations[coopId_].MarketItems[_tokenId].price;
        address seller = Cooperations[coopId_].MarketItems[_tokenId].seller;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        require(idToItemListed[_tokenId] == true, "Token must be listed before!");
        Cooperations[coopId_].MarketItems[_tokenId].owner = payable(msg.sender);
        Cooperations[coopId_].MarketItems[_tokenId].sold = true;
        Cooperations[coopId_].MarketItems[_tokenId].listed = false; 
        Cooperations[coopId_].MarketItems[_tokenId].seller = payable(address(0));
        _coopItemsSold.increment();
        _transfer(address(this), msg.sender, _tokenId);
        payable(Owner).transfer(listingPrice);

        uint256 ownerShareRatio = Cooperations[coopId_].nftOwnerShare / 100;
        uint256 coopShareRatio = Cooperations[coopId_].nftCoopShare / 100;

        uint256 coopersNum = _cooperNum.current();
        uint256 ownerShare = ownerShareRatio * price;
        uint256 cooperShare = coopShareRatio * (price / (coopersNum - 1));

        payable(seller).transfer(ownerShare);

        for(uint256 i = 0; i <= coopersNum; i++) {
            address payable cooper = Cooperations[coopId_].Cooperators[i].coopAddress;
            payable(cooper).transfer(cooperShare);
        }
        _itemsSold.increment();
        delete idToItemListed[_tokenId];
        return true;
    }
/*********************************Owner's_Functons********************** */ 
    function setListingPrice(uint256 _listingPrice) public onlyOwner {
        listingPrice = _listingPrice;
    }

    function setCoListingPrice(uint256 _coListingPrice) public onlyOwner {
        coListingPrice = _coListingPrice;
    }

    function setCandidateFee(uint256 _candidateFee) public onlyOwner {
        candidateFee = _candidateFee;
    }
/*********************************NFT_Marketplace_Functons************** */ 
    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated (
      uint256 indexed tokenId,
      address seller,
      address owner,
      uint256 price,
      bool sold,
      bool listed //added for future features
    );

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
      return listingPrice;
    }

    /* Mints a token and lists it in the marketplace */
    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
      _tokenIds.increment();
      uint256 newTokenId = _tokenIds.current();

      _mint(msg.sender, newTokenId);
      _setTokenURI(newTokenId, tokenURI);
      createMarketItem(newTokenId, price);
      return newTokenId;
    }

    function createMarketItem(
      uint256 _tokenId,
      uint256 price
    ) private {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal to listing price");
        require(idToItemListed[_tokenId] == false, "Token listed before!");
        
        idToMarketItem[_tokenId] =  MarketItem(
            _tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false,
            false //added for future features
        );

        _transfer(msg.sender, address(this), _tokenId);
        idToItemListed[_tokenId] == true;

        emit MarketItemCreated(
            _tokenId,
            msg.sender,
            address(this),
            price,
            false,
            false //added for future features
        );
    }

    /* allows someone to resell a token they have purchased */
    function resellToken(uint256 _tokenId, uint256 price) public payable {
        require(idToMarketItem[_tokenId].owner == msg.sender, "Only item owner can perform this operation");
        require(msg.value == listingPrice, "Price must be equal to listing price");
         require(idToItemListed[_tokenId] == true, "Token must be listed before!");
        idToMarketItem[_tokenId].sold = false;
        idToMarketItem[_tokenId].listed = false; //added for future features
        idToMarketItem[_tokenId].price = price;
        idToMarketItem[_tokenId].seller = payable(msg.sender);
        idToMarketItem[_tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), _tokenId);
        delete idToItemListed[_tokenId];
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(
        uint256 _tokenId
        ) public payable {
        uint price = idToMarketItem[_tokenId].price;
        address seller = idToMarketItem[_tokenId].seller;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        require(idToItemListed[_tokenId] == true, "Token must be listed before!");

        idToMarketItem[_tokenId].owner = payable(msg.sender);
        idToMarketItem[_tokenId].sold = true;
        idToMarketItem[_tokenId].listed = true; //added for future features
        idToMarketItem[_tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, _tokenId);
        payable(Owner).transfer(listingPrice);
        payable(seller).transfer(msg.value);

        delete idToItemListed[_tokenId];
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
            uint currentId = i + 1;
            MarketItem storage currentItem = idToMarketItem[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
            itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
            uint currentId = i + 1;
            MarketItem storage currentItem = idToMarketItem[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
            itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
            uint currentId = i + 1;
            MarketItem storage currentItem = idToMarketItem[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
            }
        }
        return items;
    }
}