pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "github.com/Open-Attestation/token-registry/contracts/ERC721.sol";
import "./Ownable.sol";
import "./Pausable.sol";
contract TicketSystem is ERC721, Ownable, Pausable {
    
    // basic parameter
    string public eventname;
    string public eventsymbol;
    address payable withdrawalAddress;
    uint64 public eventStartDate;
    uint64 public ticket_Supply;
    uint256 public initialTicketPrice;
    uint64 public maxPriceFactor;
    uint64 public transferFee;
    
    // constructor
    constructor(
        string memory Event_Name, 
        string memory Event_Symbol, 
        uint64 StartDate,
        uint64 Ticket_Supply, 
        uint256 Initial_Ticket_Price,
        uint64 Max_Price_Factor, 
        uint64 Transfer_Fee
    ) public payable{
        eventname = Event_Name;
        eventsymbol = Event_Symbol;
        withdrawalAddress = msg.sender;
        eventStartDate = uint64(StartDate);
        ticket_Supply = uint64(Ticket_Supply);
        initialTicketPrice = uint256(Initial_Ticket_Price);
        maxPriceFactor = uint64(Max_Price_Factor);
        transferFee = uint64(Transfer_Fee);
    }
    
    // ticket 
    struct Ticket {
        uint256 price;
        bool forSale;
        bool used;
    }
    //mapping (Ticket => uint) public mappedUsers;
    // create list of Ticket
    Ticket[] tickets;
    mapping (uint=>address) internal TicketIndexToAddr;
    mapping (address=>uint) public addrTicketCount; 

    // define events
    event TicketCreated(address _by, uint256 _ticketId);
    event TicketDestroyed(address _by, uint256 _ticketId);
    event TicketForSale(address _by, uint256 _ticketId, uint256 _price);
    event TicketSaleCancelled(address _by, uint256 _ticketId);
    event TicketSold(address _by, address _to, uint256 _ticketId, uint256 _price);
    event TicketPriceChanged(address _by, uint256 _ticketId, uint256 _price);
    event BalanceWithdrawn(address _by, address _to, uint256 _amount);
    event LogUnit(uint256 p);

    // set value functions
    // check if price overflow limit
    modifier priceCap(uint256 _price){
        uint256 maxPrice = initialTicketPrice * maxPriceFactor;
        require((_price <= maxPrice),"The price exceed the limit");
        _;
    }

    //check if event started
    modifier EventNotStarted(){
        require((uint64(now) < eventStartDate),"event has already started");
        _;
    }
    
    // check supply
    modifier haveSupply() {
        require((tickets.length < ticket_Supply),"no more new tickets available");
        _;
    } 

    // check if ticket not being used
    modifier isUsed(uint256 _ticketId) {
        require(tickets[_ticketId].used != true,"ticket already used");
        _;
    }
    
    // check if owner, only owner of ticket can sell the tickets
        modifier isTicketOwner(uint256 _ticketId) {
        require((ownerOf(_ticketId) == msg.sender),"Wrong Ownership, only ticket onwer can transact");
        _;
    }

    // set value functions
    function setTicketUsed(uint256 _ticketId)
    public
    onlyOwner
    {
        tickets[_ticketId].used = true;
    }

    // set individual ticket price
    function setTicketPrice(uint256 _price, uint256 _ticketId) 
    public 
    //EventNotStarted
    isUsed(_ticketId)
    isTicketOwner(_ticketId) 
    priceCap(_price) 
    {
        tickets[_ticketId].price = _price;
        emit TicketPriceChanged(msg.sender, _ticketId, _price);
    }

    // set eventStartDate
    function setEventStartDate(uint64 _eventStartDate) 
    public 
    // EventNotStarted 
    onlyOwner 
    {
        eventStartDate = _eventStartDate;
    }

    // set ticket supply
    function setSupply(uint64 _ticketSupply)     
    public 
    // EventNotStarted 
    onlyOwner 
    {
        ticket_Supply = _ticketSupply;
    }

    // set max price
    function setMaxPrice(uint64 _maxPriceFactor) 
    public 
    // EventNotStarted 
    onlyOwner 
    {
        maxPriceFactor = _maxPriceFactor;
    }

    // set withdrawal address
    function setWithdrawalAddress(address payable _addr) 
    public 
    onlyOwner 
    {
        require((_addr != address(0)),"It is not a valid address");
        withdrawalAddress = _addr;
    }

    // set ticket to sell
    
    function setTicketForSale(uint256 _ticketId) 
    external 
    // EventNotStarted 
    //whenNotPaused
    isUsed(_ticketId)
    isTicketOwner(_ticketId) 
    {
        tickets[_ticketId].forSale = true;
        emit TicketForSale(msg.sender, _ticketId, tickets[_ticketId].price);
    }

    function cancelTicketSale(uint256 _ticketId) 
    external 
    // EventNotStarted
    //whenNotPaused
    isTicketOwner(_ticketId)
    {
        tickets[_ticketId].forSale = false;
        emit TicketSaleCancelled(msg.sender, _ticketId);
    }

    // get value functions
    // get a ticket
    function getTicket(uint256 _id) 
    external 
    view 
    returns (
        uint256 price, 
        bool forSale,
        bool used
    )
    {
        price = uint256(tickets[_id].price);
        forSale = bool(tickets[_id].forSale);
        used = bool(tickets[_id].used);
    }

    // get ticket price
    function getTicketPrice(uint256 _ticketId) 
    public 
    view 
    returns (uint256) 
    {
        return tickets[_ticketId].price;
    }

    // get maximum price
    function getMaxPrice(uint256 _ticketId) 
    public 
    view 
    returns (uint256) 
    {
        return tickets[_ticketId].price * maxPriceFactor;
    }

    // get ticket status (used or not)
    function getTicketIfUsed(uint256 _ticketId) 
    public 
    view 
    returns (bool) 
    {
        return tickets[_ticketId].used;
    }

    // get if ticket being sold already
    function getTicketIfSale(uint256 _ticketId) 
    public 
    view 
    returns (bool) 
    {
        return tickets[_ticketId].forSale;
    }

    // get owner
    function checkTicketOwnership(uint256 _ticketId) 
    external 
    view 
    returns (bool) 
    {
        require((ownerOf(_ticketId) == msg.sender),"No one own this ticket");
        return true;
    }

    // create ticket
    function _createTicket() 
    internal 
    //EventNotStarted 
    haveSupply
    returns (uint256) 
    {
        Ticket memory _ticket = Ticket({
            price: initialTicketPrice,
            forSale: bool(false),
            used: bool(false)
        });
        tickets.push(_ticket);
        uint256 newTicketId =  tickets.length-1;
        emit LogUnit(newTicketId);
        return newTicketId;
    }
    
    function buyTicket(uint256 pricepaid) 
    external 
    //public
    payable 
    // EventNotStarted 
//    whenNotPaused
    {   
        require((pricepaid >= initialTicketPrice),"not enough money");
        require((balanceOf(msg.sender)<=1),"exceed ticket limit");
        
        if(pricepaid > initialTicketPrice)
        {
            msg.sender.transfer(msg.value.sub(initialTicketPrice));
        }

        uint256 _ticketId = _createTicket();
        _mint(msg.sender, _ticketId);
        emit TicketCreated(msg.sender, _ticketId);
    }

    // print all ticket
    function printAll() 
    view 
    public 
    returns (Ticket[] memory)
    {
        Ticket[] memory idList ;
        uint counter = 0;    
        for (uint i = 0; i < tickets.length; i++) {
                idList[i]=tickets[i];
                counter++;
            }
        
        return idList;
    }
    
    // add a ticket
    function addticket()external{
        uint256 _ticketId = _createTicket();
        _mint(msg.sender, _ticketId);
        emit TicketCreated(msg.sender, _ticketId);
    }

}